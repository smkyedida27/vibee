package com.puzzlehub.economy;

import com.puzzlehub.common.ApiException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/** Server-authoritative wallet with an append-only, idempotent ledger. */
@Service
public class WalletService {

    public enum Currency { COINS, GEMS }

    public record Wallet(long coins, long gems) {}

    public enum Sku {
        HEART_REFILL(30, 0), HINT_PACK_5(20, 0), COINS_1000(25, 1000),
        /** Continues cost 12 then 24 gems; the price is the maximum and the client sends the actual amount. */
        CONTINUE(24, 0);

        final int gemCost;
        final int coinGrant;

        Sku(int gemCost, int coinGrant) {
            this.gemCost = gemCost;
            this.coinGrant = coinGrant;
        }
    }

    public record SpendResult(Sku sku, Wallet wallet) {}

    private final JdbcClient db;

    public WalletService(JdbcClient db) {
        this.db = db;
    }

    @Transactional(readOnly = true)
    public Wallet get(UUID userId) {
        return db.sql("select coins, gems from wallets where user_id = :u").param("u", userId)
                .query((rs, i) -> new Wallet(rs.getLong(1), rs.getLong(2))).optional().orElse(new Wallet(0, 0));
    }

    /**
     * Applies {@code delta} once per (user, key, currency). Returns false if the key was already applied.
     * Must run inside the caller's transaction so grants are atomic with their cause.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public boolean apply(UUID userId, Currency currency, long delta, String reason, String key) {
        int inserted = db.sql("""
                insert into wallet_ledger (user_id, currency, delta, reason, idempotency_key)
                values (:u, :c, :d, :r, :k) on conflict do nothing""")
                .param("u", userId).param("c", currency.name()).param("d", delta).param("r", reason).param("k", key)
                .update();
        if (inserted == 0) return false;
        db.sql("insert into wallets (user_id) values (:u) on conflict do nothing").param("u", userId).update();
        String column = currency == Currency.COINS ? "coins" : "gems";
        int updated = db.sql("update wallets set " + column + " = " + column + " + :d where user_id = :u and "
                        + column + " + :d >= 0")
                .param("d", delta).param("u", userId).update();
        if (updated == 0) {
            throw new ApiException(org.springframework.http.HttpStatus.CONFLICT, "INSUFFICIENT_FUNDS",
                    "Not enough " + column);
        }
        return true;
    }

    @Transactional
    public SpendResult spend(UUID userId, Sku sku, String key) {
        return spend(userId, sku, key, null);
    }

    /**
     * Spends {@code gems} (default: the full price) for {@code sku}. A smaller amount means the device paid
     * the rest with free local gems; item effects are applied on the device, so this grants nothing extra.
     * The server-side coin mirror is only credited when the full price was paid here.
     */
    @Transactional
    public SpendResult spend(UUID userId, Sku sku, String key, Integer gems) {
        int amount = gems == null ? sku.gemCost : gems;
        if (amount > sku.gemCost) {
            throw ApiException.badRequest("VALIDATION_FAILED", "gems: must be between 1 and the price of " + sku.name());
        }
        // The SKU is part of the key so a replayed key can't be reused to claim a different item.
        String ledgerKey = "spend:" + sku.name() + ":" + key;
        boolean applied = apply(userId, Currency.GEMS, -amount, "SPEND_" + sku.name(), ledgerKey);
        if (applied && sku.coinGrant > 0 && amount == sku.gemCost) {
            apply(userId, Currency.COINS, sku.coinGrant, "SPEND_" + sku.name(), ledgerKey);
        }
        return new SpendResult(sku, get(userId));
    }
}
