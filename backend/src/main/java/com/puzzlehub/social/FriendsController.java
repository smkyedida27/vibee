package com.puzzlehub.social;

import com.puzzlehub.common.ApiException;
import com.puzzlehub.identity.AuthUser;
import com.puzzlehub.identity.User;
import com.puzzlehub.identity.UserRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/** Mutual friendships created by sharing a friend code. */
@RestController
@RequestMapping("/api/v1/me/friends")
public class FriendsController {

    static final int MAX_FRIENDS = 200;

    public record Friend(UUID userId, String displayName, int avatarId, String country, String friendCode) {}

    public record AddFriend(@NotBlank @Pattern(regexp = "[A-Za-z0-9]{8}") String friendCode) {}

    private final JdbcClient db;
    private final UserRepository users;

    public FriendsController(JdbcClient db, UserRepository users) {
        this.db = db;
        this.users = users;
    }

    @GetMapping
    public List<Friend> list(AuthUser user) {
        return db.sql("""
                select u.id, u.display_name, u.avatar_id, u.country, u.friend_code
                from friendships f join users u on u.id = f.friend_id
                where f.user_id = :u order by u.display_name""")
                .param("u", user.id())
                .query((rs, i) -> new Friend(rs.getObject(1, UUID.class), rs.getString(2), rs.getInt(3),
                        rs.getString(4), rs.getString(5)))
                .list();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Friend add(AuthUser user, @Valid @RequestBody AddFriend body) {
        User friend = users.findByFriendCode(body.friendCode().toUpperCase())
                .orElseThrow(() -> ApiException.notFound("Friend code"));
        if (friend.id().equals(user.id())) throw ApiException.badRequest("SELF_FRIEND", "You cannot add yourself");
        long count = db.sql("select count(*) from friendships where user_id = :u").param("u", user.id())
                .query(Long.class).single();
        if (count >= MAX_FRIENDS) throw ApiException.conflict("FRIEND_LIMIT", "Friend limit reached");
        for (UUID[] pair : new UUID[][]{{user.id(), friend.id()}, {friend.id(), user.id()}}) {
            db.sql("insert into friendships (user_id, friend_id) values (:a, :b) on conflict do nothing")
                    .param("a", pair[0]).param("b", pair[1]).update();
        }
        return new Friend(friend.id(), friend.displayName(), friend.avatarId(), friend.country(), friend.friendCode());
    }

    @DeleteMapping("/{friendId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void remove(AuthUser user, @PathVariable UUID friendId) {
        db.sql("delete from friendships where (user_id = :a and friend_id = :b) or (user_id = :b and friend_id = :a)")
                .param("a", user.id()).param("b", friendId).update();
    }
}
