package com.puzzlehub.store;

import java.time.Instant;

/** Verifies a Google Play purchase token with Google. */
public interface PurchaseVerifier {

    /** @param expiresAt subscription expiry (null for one-time products) */
    record Verification(boolean valid, String orderId, Instant expiresAt) {}

    Verification verify(Product product, String purchaseToken);
}
