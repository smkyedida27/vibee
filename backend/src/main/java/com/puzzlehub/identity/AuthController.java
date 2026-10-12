package com.puzzlehub.identity;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    public record GuestRequest(@Size(max = 128) String deviceId) {}

    public record RefreshRequest(@NotBlank @Size(max = 256) String refreshToken) {}

    public record FirebaseRequest(@NotBlank @Size(max = 4096) String idToken) {}

    private final AuthService auth;

    public AuthController(AuthService auth) {
        this.auth = auth;
    }

    @PostMapping("/guest")
    public AuthService.Tokens guest(@Valid @RequestBody(required = false) GuestRequest body) {
        return auth.guest(body == null ? null : body.deviceId());
    }

    @PostMapping("/refresh")
    public AuthService.Tokens refresh(@Valid @RequestBody RefreshRequest body) {
        return auth.refresh(body.refreshToken());
    }

    @PostMapping("/firebase")
    public AuthService.Tokens firebase(@Valid @RequestBody FirebaseRequest body) {
        return auth.firebase(body.idToken(), AuthUserArgumentResolver.current());
    }
}
