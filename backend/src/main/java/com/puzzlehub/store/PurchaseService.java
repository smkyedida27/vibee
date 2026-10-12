package com.puzzlehub.store;

import com.puzzlehub.common.ApiException;
import com.puzzlehub.economy.WalletService;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

@Service
public class PurchaseService {

    public record Entitlements(boolean removeAds, Instant vipUntil, boolean vipActive) {}

    public record Grant(String productId, String status, WalletService.Wallet wallet, Entitlements entitlements) {}

    private final JdbcClient db;
    private final PurchaseVerifier verifier;
    private final WalletService wallet;
    private final Clock clock;

    public PurchaseService(JdbcClient db, PurchaseVerifier verifier, WalletService wallet, Clock clock) {
        this.db = db;
        this.verifier = verifier;
        this.wallet = wallet;
        this.clock = clock;
    }

    /** Idempotent per purchase token; a token can never be credited to two accounts. */
    @Transactional
    public Grant verifyGoogle(UUID userId, String productId, String purchaseToken) {
        Product product = Product.find(productId)
                .orElseThrow(() -> ApiException.badRequest("UNKNOWN_PRODUCT", "Unknown product"));
        Optional<UUID> owner = db.sql("select user_id from purchases where purchase_token = :t for update")
                .param("t", purchaseToken).query((rs, i) -> rs.getObject(1, UUID.class)).optional();
        if (owner.isPresent() && !userId.equals(owner.get())) {
            throw ApiException.conflict("PURCHASE_ALREADY_CLAIMED", "This purchase belongs to another account");
        }
        if (owner.isEmpty() || product.type() == Product.Type.SUBSCRIPTION) {
            PurchaseVerifier.Verification v = verifier.verify(product, purchaseToken);
            if (!v.valid()) throw ApiException.badRequest("PURCHASE_INVALID", "Purchase could not be verified");
            if (owner.isEmpty()) {
                try {
                    db.sql("insert into purchases (id, user_id, product_id, purchase_token, order_id) values (:id, :u, :p, :t, :o)")
                            .param("id", UUID.randomUUID()).param("u", userId).param("p", productId)
                            .param("t", purchaseToken).param("o", v.orderId()).update();
                } catch (DuplicateKeyException e) {
                    throw ApiException.conflict("PURCHASE_IN_PROGRESS", "Purchase is being processed, retry");
                }
            }
            grant(userId, product, purchaseToken, v);
        }
        return new Grant(productId, "GRANTED", wallet.get(userId), entitlements(userId));
    }

    private void grant(UUID userId, Product product, String token, PurchaseVerifier.Verification v) {
        switch (product.type()) {
            case CONSUMABLE -> wallet.apply(userId, WalletService.Currency.GEMS, product.gems(),
                    "PURCHASE_" + product.productId(), "purchase:" + token);
            case NON_CONSUMABLE -> db.sql("""
                    insert into entitlements (user_id, remove_ads) values (:u, true)
                    on conflict (user_id) do update set remove_ads = true""").param("u", userId).update();
            case SUBSCRIPTION -> db.sql("""
                    insert into entitlements (user_id, vip_until) values (:u, :e)
                    on conflict (user_id) do update set vip_until = greatest(coalesce(entitlements.vip_until, :e), :e)""")
                    .param("u", userId).param("e", v.expiresAt() == null ? null : Timestamp.from(v.expiresAt()))
                    .update();
        }
    }

    @Transactional(readOnly = true)
    public Entitlements entitlements(UUID userId) {
        return db.sql("select remove_ads, vip_until from entitlements where user_id = :u").param("u", userId)
                .query((rs, i) -> {
                    Timestamp vip = rs.getTimestamp(2);
                    Instant until = vip == null ? null : vip.toInstant();
                    return new Entitlements(rs.getBoolean(1), until, until != null && until.isAfter(clock.instant()));
                })
                .optional().orElse(new Entitlements(false, null, false));
    }
}
