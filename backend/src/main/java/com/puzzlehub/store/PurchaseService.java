package com.puzzlehub.store;

import com.puzzlehub.common.ApiException;
import com.puzzlehub.economy.WalletService;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
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
    private final TransactionTemplate tx;

    public PurchaseService(JdbcClient db, PurchaseVerifier verifier, WalletService wallet, Clock clock,
                           PlatformTransactionManager txManager) {
        this.tx = new TransactionTemplate(txManager);
        this.db = db;
        this.verifier = verifier;
        this.wallet = wallet;
        this.clock = clock;
    }

    /** A purchase row; {@code owner} is null once the buyer deleted their account. */
    private record Row(UUID owner) {}

    /**
     * Idempotent per purchase token; a token can never be credited to two accounts.
     * Google is called before the transaction opens, so a slow Play API never holds a pooled
     * connection or a row lock.
     */
    public Grant verifyGoogle(UUID userId, String productId, String purchaseToken) {
        Product product = Product.find(productId)
                .orElseThrow(() -> ApiException.badRequest("UNKNOWN_PRODUCT", "Unknown product"));
        PurchaseVerifier.Verification v = verifier.verify(product, purchaseToken);
        if (!v.valid()) throw ApiException.badRequest("PURCHASE_INVALID", "Purchase could not be verified");
        return tx.execute(status -> record(userId, product, purchaseToken, v));
    }

    private Grant record(UUID userId, Product product, String purchaseToken, PurchaseVerifier.Verification v) {
        String productId = product.productId();
        Optional<Row> row = db.sql("select user_id from purchases where purchase_token = :t for update")
                .param("t", purchaseToken).query((rs, i) -> new Row(rs.getObject(1, UUID.class))).optional();
        Optional<UUID> owner = row.map(Row::owner);
        if (row.isPresent() && !userId.equals(row.get().owner())) {
            // Consumables (gems) are granted exactly once, even if the buyer deleted their account.
            // Remove-ads and VIP follow whoever holds the Play account (a reinstall creates a new
            // guest): they move over, and the previous account loses them.
            if (product.type() == Product.Type.CONSUMABLE) {
                throw ApiException.conflict("PURCHASE_ALREADY_CLAIMED", "This purchase belongs to another account");
            }
            UUID previous = row.get().owner();
            db.sql("update purchases set user_id = :u where purchase_token = :t")
                    .param("u", userId).param("t", purchaseToken).update();
            if (previous != null) revokeEntitlement(previous, product);
            grantEntitlement(userId, product, v);
            return new Grant(productId, "GRANTED", wallet.get(userId), entitlements(userId));
        }
        if (owner.isEmpty() || product.type() == Product.Type.SUBSCRIPTION) {
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
        // Gems are granted once per purchase token (bundles included); entitlements may move.
        if (product.gems() > 0) {
            wallet.apply(userId, WalletService.Currency.GEMS, product.gems(), "PURCHASE_" + product.productId(),
                    "purchase:" + token);
        }
        grantEntitlement(userId, product, v);
    }

    /** Removes what {@code product} granted, unless the user still owns another product of the same type. */
    private void revokeEntitlement(UUID userId, Product product) {
        List<String> sameType = Product.CATALOG.stream().filter(p -> p.type() == product.type())
                .map(Product::productId).toList();
        boolean stillOwns = db.sql("""
                select exists(select 1 from purchases where user_id = :u and product_id in (:ids))""")
                .param("u", userId).param("ids", sameType).query(Boolean.class).single();
        if (stillOwns) return;
        switch (product.type()) {
            case CONSUMABLE -> { }
            case NON_CONSUMABLE -> db.sql("update entitlements set remove_ads = false where user_id = :u")
                    .param("u", userId).update();
            case SUBSCRIPTION -> db.sql("update entitlements set vip_until = null where user_id = :u")
                    .param("u", userId).update();
        }
    }

    private void grantEntitlement(UUID userId, Product product, PurchaseVerifier.Verification v) {
        switch (product.type()) {
            case CONSUMABLE -> { }
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
