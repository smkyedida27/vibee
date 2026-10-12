package com.puzzlehub.economy;

import com.puzzlehub.identity.AuthUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/me")
public class WalletController {

    public record SpendRequest(@NotNull WalletService.Sku sku,
                               @NotNull @Pattern(regexp = "[A-Za-z0-9._:-]{8,128}") String idempotencyKey) {}

    private final WalletService wallet;
    private final DailyRewardService rewards;

    public WalletController(WalletService wallet, DailyRewardService rewards) {
        this.wallet = wallet;
        this.rewards = rewards;
    }

    @GetMapping("/wallet")
    public WalletService.Wallet wallet(AuthUser user) {
        return wallet.get(user.id());
    }

    @PostMapping("/wallet/spend")
    public WalletService.SpendResult spend(AuthUser user, @Valid @RequestBody SpendRequest body) {
        return wallet.spend(user.id(), body.sku(), body.idempotencyKey());
    }

    @PostMapping("/rewards/daily-claim")
    public DailyRewardService.Claim claim(AuthUser user) {
        return rewards.claim(user.id());
    }
}
