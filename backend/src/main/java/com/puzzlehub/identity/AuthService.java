package com.puzzlehub.identity;

import com.puzzlehub.common.ApiException;
import com.puzzlehub.common.Hashing;
import com.puzzlehub.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.UUID;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);
    private static final SecureRandom RANDOM = new SecureRandom();

    public record Tokens(UUID userId, String accessToken, String refreshToken, long expiresIn) {}

    private final UserRepository users;
    private final JwtService jwt;
    private final JdbcClient db;
    private final FirebaseTokenVerifier firebase;
    private final AppProperties props;
    private final Clock clock;
    private final TransactionTemplate revokeAll;

    public AuthService(UserRepository users, JwtService jwt, JdbcClient db, FirebaseTokenVerifier firebase,
                       AppProperties props, Clock clock, PlatformTransactionManager txManager) {
        this.revokeAll = new TransactionTemplate(txManager);
        this.revokeAll.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        this.users = users;
        this.jwt = jwt;
        this.db = db;
        this.firebase = firebase;
        this.props = props;
        this.clock = clock;
    }

    @Transactional
    public Tokens guest(String deviceId) {
        User user = users.createGuest(deviceId, null);
        return issue(user);
    }

    /** Rotates the refresh token. Re-use of an already rotated token revokes the whole family (token theft signal). */
    @Transactional
    public Tokens refresh(String refreshToken) {
        var row = db.sql("select id, user_id, expires_at, revoked_at from refresh_tokens where token_hash = :h for update")
                .param("h", Hashing.sha256Hex(refreshToken))
                .query((rs, i) -> new Object[]{rs.getObject("id", UUID.class), rs.getObject("user_id", UUID.class),
                        rs.getTimestamp("expires_at").toInstant(), rs.getTimestamp("revoked_at")})
                .optional()
                .orElseThrow(AuthService::invalidRefresh);
        UUID tokenId = (UUID) row[0];
        UUID userId = (UUID) row[1];
        Instant expires = (Instant) row[2];
        if (row[3] != null) {
            log.warn("Refresh token reuse detected for user {}; revoking all sessions", userId);
            revokeAll.executeWithoutResult(tx -> db.sql(
                    "update refresh_tokens set revoked_at = now() where user_id = :u and revoked_at is null")
                    .param("u", userId).update());
            throw invalidRefresh();
        }
        if (expires.isBefore(clock.instant())) throw invalidRefresh();
        db.sql("update refresh_tokens set revoked_at = now() where id = :id").param("id", tokenId).update();
        return issue(users.findById(userId).orElseThrow(AuthService::invalidRefresh));
    }

    /**
     * Links a Firebase identity to the calling guest, or signs in to the account already linked to it.
     * Without a caller, signs in (or creates) the account for that Firebase user.
     */
    @Transactional
    public Tokens firebase(String idToken, AuthUser caller) {
        String uid = firebase.verify(idToken);
        var linked = users.findByFirebaseUid(uid);
        if (linked.isPresent()) return issue(linked.get());
        if (caller != null) {
            User current = users.findById(caller.id()).orElseThrow(AuthService::invalidRefresh);
            if (current.firebaseUid() != null) {
                throw ApiException.conflict("ALREADY_LINKED", "This account is already linked to another sign-in");
            }
            users.linkFirebase(current.id(), uid);
            return issue(users.findById(current.id()).orElseThrow());
        }
        return issue(users.createGuest(null, uid));
    }

    private Tokens issue(User user) {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        String refresh = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        db.sql("insert into refresh_tokens (id, user_id, token_hash, expires_at) values (:id, :u, :h, :exp)")
                .param("id", UUID.randomUUID()).param("u", user.id()).param("h", Hashing.sha256Hex(refresh))
                .param("exp", Timestamp.from(clock.instant().plus(props.jwt().refreshTtl())))
                .update();
        return new Tokens(user.id(), jwt.issueAccessToken(user.id(), user.roles()), refresh, jwt.accessTtlSeconds());
    }

    private static ApiException invalidRefresh() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH_TOKEN", "Refresh token is invalid or expired");
    }
}
