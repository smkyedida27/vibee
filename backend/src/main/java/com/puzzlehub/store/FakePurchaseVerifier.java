package com.puzzlehub.store;

import java.time.Clock;
import java.time.Duration;

/** Dev/test only: tokens starting with {@code test-valid-} are accepted. Refused in the prod profile. */
public class FakePurchaseVerifier implements PurchaseVerifier {

    private final Clock clock;

    public FakePurchaseVerifier(Clock clock) {
        this.clock = clock;
    }

    @Override
    public Verification verify(Product product, String purchaseToken) {
        if (!purchaseToken.startsWith("test-valid-")) return new Verification(false, null, null);
        return new Verification(true, "GPA.TEST-" + purchaseToken.hashCode(),
                product.type() == Product.Type.SUBSCRIPTION ? clock.instant().plus(Duration.ofDays(30)) : null);
    }
}
