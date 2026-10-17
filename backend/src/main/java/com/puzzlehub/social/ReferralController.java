package com.puzzlehub.social;

import com.puzzlehub.identity.AuthUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Invite a friend: share your code, they redeem it, you both get gems and become friends. */
@RestController
@RequestMapping("/api/v1/me/referral")
public class ReferralController {

    public record Redeem(@NotBlank @Pattern(regexp = "[A-Za-z0-9]{8}") String code) {}

    private final ReferralService referrals;

    public ReferralController(ReferralService referrals) {
        this.referrals = referrals;
    }

    @GetMapping
    public ReferralService.Stats stats(AuthUser user) {
        return referrals.stats(user.id());
    }

    @PostMapping("/redeem")
    public ReferralService.Redeemed redeem(AuthUser user, @Valid @RequestBody Redeem body) {
        return referrals.redeem(user.id(), body.code());
    }
}
