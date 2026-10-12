package com.puzzlehub.store;

import java.util.List;
import java.util.Optional;

/** Google Play catalog. Prices live in Play Console (localised); the server only knows what each grants. */
public record Product(String productId, Type type, String title, String description, int gems) {

    public enum Type { CONSUMABLE, NON_CONSUMABLE, SUBSCRIPTION }

    public static final List<Product> CATALOG = List.of(
            new Product("gems_small", Type.CONSUMABLE, "Handful of Gems", "80 gems", 80),
            new Product("gems_medium", Type.CONSUMABLE, "Pouch of Gems", "500 gems", 500),
            new Product("gems_large", Type.CONSUMABLE, "Chest of Gems", "1200 gems", 1200),
            new Product("gems_mega", Type.CONSUMABLE, "Vault of Gems", "3000 gems", 3000),
            new Product("remove_ads", Type.NON_CONSUMABLE, "Remove Ads", "No interstitial or banner ads, forever", 0),
            new Product("vip_monthly", Type.SUBSCRIPTION, "VIP Pass",
                    "No ads, unlimited hearts, 2× coins and 3 free hints every day", 0));

    public static Optional<Product> find(String id) {
        return CATALOG.stream().filter(p -> p.productId().equals(id)).findFirst();
    }
}
