package com.puzzlehub.social;

import com.puzzlehub.common.ApiException;
import com.puzzlehub.economy.WalletService;
import com.puzzlehub.identity.User;
import com.puzzlehub.identity.UserRepository;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.util.UUID;

/**
 * Invite codes are friend codes. Redeeming one makes the two players friends and grants both
 * server-wallet gems. Guest accounts are cheap, so rewards are bounded: only new accounts can
 * redeem, each account redeems once, and an inviter is rewarded for at most {@link #MAX_REWARDED}.
 */
@Service
public class ReferralService {

    static final int INVITEE_GEMS = 20;
    static final int INVITER_GEMS = 20;
    static final int MAX_REWARDED = 25;
    static final Duration REDEEM_WINDOW = Duration.ofDays(7);

    public record Redeemed(FriendsController.Friend inviter, int gemsGranted, WalletService.Wallet wallet) {}

    public record Stats(String inviteCode, long invited, long rewarded, int maxRewarded, int gemsPerInvite,
                        boolean redeemed, boolean canRedeem) {}

    private final JdbcClient db;
    private final UserRepository users;
    private final WalletService wallet;
    private final Clock clock;

    public ReferralService(JdbcClient db, UserRepository users, WalletService wallet, Clock clock) {
        this.db = db;
        this.users = users;
        this.wallet = wallet;
        this.clock = clock;
    }

    @Transactional
    public Redeemed redeem(UUID inviteeId, String code) {
        User invitee = users.findById(inviteeId).orElseThrow(() -> ApiException.notFound("User"));
        User inviter = users.findByFriendCode(code.toUpperCase()).orElseThrow(() -> ApiException.notFound("Invite code"));
        if (inviter.id().equals(inviteeId)) throw ApiException.badRequest("SELF_INVITE", "You can't use your own invite code");
        if (invitee.createdAt().plus(REDEEM_WINDOW).isBefore(clock.instant())) {
            throw ApiException.conflict("INVITE_EXPIRED", "Invite codes can only be used in your first week");
        }
        // Serialise redemptions per inviter so the reward cap can't be raced past.
        db.sql("select id from users where id = :u for update").param("u", inviter.id()).query(UUID.class).single();
        long rewardedSoFar = db.sql("select count(*) from referrals where inviter_id = :u and rewarded")
                .param("u", inviter.id()).query(Long.class).single();
        boolean rewarded = rewardedSoFar < MAX_REWARDED;
        int inserted = db.sql("""
                insert into referrals (invitee_id, inviter_id, rewarded) values (:invitee, :inviter, :rewarded)
                on conflict (invitee_id) do nothing""")
                .param("invitee", inviteeId).param("inviter", inviter.id()).param("rewarded", rewarded).update();
        if (inserted == 0) throw ApiException.conflict("ALREADY_REDEEMED", "You've already used an invite code");

        for (UUID[] pair : new UUID[][]{{inviteeId, inviter.id()}, {inviter.id(), inviteeId}}) {
            db.sql("insert into friendships (user_id, friend_id) values (:a, :b) on conflict do nothing")
                    .param("a", pair[0]).param("b", pair[1]).update();
        }
        // The invitee always gets the welcome gift; the inviter only while under the cap.
        wallet.apply(inviteeId, WalletService.Currency.GEMS, INVITEE_GEMS, "REFERRAL_INVITEE", "referral:" + inviteeId);
        if (rewarded) {
            wallet.apply(inviter.id(), WalletService.Currency.GEMS, INVITER_GEMS, "REFERRAL_INVITER", "referral:" + inviteeId);
        }
        var friend = new FriendsController.Friend(inviter.id(), inviter.displayName(), inviter.avatarId(),
                inviter.country(), inviter.friendCode());
        return new Redeemed(friend, INVITEE_GEMS, wallet.get(inviteeId));
    }

    @Transactional(readOnly = true)
    public Stats stats(UUID userId) {
        User u = users.findById(userId).orElseThrow(() -> ApiException.notFound("User"));
        long invited = db.sql("select count(*) from referrals where inviter_id = :u").param("u", userId)
                .query(Long.class).single();
        long rewarded = db.sql("select count(*) from referrals where inviter_id = :u and rewarded").param("u", userId)
                .query(Long.class).single();
        boolean redeemed = db.sql("select exists(select 1 from referrals where invitee_id = :u)").param("u", userId)
                .query(Boolean.class).single();
        boolean inWindow = !u.createdAt().plus(REDEEM_WINDOW).isBefore(clock.instant());
        return new Stats(u.friendCode(), invited, rewarded, MAX_REWARDED, INVITER_GEMS, redeemed, !redeemed && inWindow);
    }
}
