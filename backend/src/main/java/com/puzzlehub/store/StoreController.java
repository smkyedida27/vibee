package com.puzzlehub.store;

import com.puzzlehub.identity.AuthUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;
import java.util.List;

@RestController
@RequestMapping("/api/v1")
public class StoreController {

    public record VerifyRequest(@NotBlank @Size(max = 64) String productId, @NotBlank @Size(max = 1024) String purchaseToken) {}

    private final PurchaseService purchases;

    public StoreController(PurchaseService purchases) {
        this.purchases = purchases;
    }

    @GetMapping("/store/products")
    public ResponseEntity<List<Product>> products() {
        return ResponseEntity.ok().cacheControl(CacheControl.maxAge(Duration.ofHours(1)).cachePublic()).body(Product.CATALOG);
    }

    @PostMapping("/purchases/google/verify")
    public PurchaseService.Grant verify(AuthUser user, @Valid @RequestBody VerifyRequest body) {
        return purchases.verifyGoogle(user.id(), body.productId(), body.purchaseToken());
    }

    @GetMapping("/me/entitlements")
    public PurchaseService.Entitlements entitlements(AuthUser user) {
        return purchases.entitlements(user.id());
    }
}
