package com.puzzlehub.notifications;

import com.puzzlehub.identity.AuthUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** FCM registration tokens. A token moves to the latest user that registers it (device sign-in change). */
@RestController
@RequestMapping("/api/v1/me/push-token")
public class PushTokenController {

    public record Register(@NotBlank @Size(max = 4096) String token, @Pattern(regexp = "ANDROID|IOS|WEB") String platform) {}

    private final JdbcClient db;

    public PushTokenController(JdbcClient db) {
        this.db = db;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void register(AuthUser user, @Valid @RequestBody Register body) {
        db.sql("""
                insert into push_tokens (token, user_id, platform, updated_at) values (:t, :u, :p, now())
                on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, updated_at = now()""")
                .param("t", body.token()).param("u", user.id())
                .param("p", body.platform() == null ? "ANDROID" : body.platform())
                .update();
    }
}
