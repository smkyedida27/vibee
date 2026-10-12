package com.puzzlehub.social;

import com.puzzlehub.common.ApiException;
import com.puzzlehub.identity.AuthUser;
import com.puzzlehub.identity.User;
import com.puzzlehub.identity.UserRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.DateTimeException;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/me")
public class ProfileController {

    public record Profile(UUID userId, String displayName, int avatarId, String country, String locale, String timezone,
                          String reminderTime, boolean notificationsEnabled, String friendCode, boolean linked,
                          Instant createdAt) {
        static Profile of(User u) {
            return new Profile(u.id(), u.displayName(), u.avatarId(), u.country(), u.locale(), u.timezone(),
                    u.reminderTime() == null ? null : u.reminderTime().toString(), u.notificationsEnabled(),
                    u.friendCode(), u.firebaseUid() != null, u.createdAt());
        }
    }

    public record Preferences(
            @Pattern(regexp = "[\\p{L}\\p{N} _.-]{2,20}") String displayName,
            @Min(0) @Max(63) Integer avatarId,
            @Pattern(regexp = "[A-Z]{2}") String country,
            @Pattern(regexp = "[a-z]{2,3}(-[A-Z]{2})?") String locale,
            @Pattern(regexp = "[A-Za-z_/+-]{1,40}") String timezone,
            @Pattern(regexp = "([01]\\d|2[0-3]):[0-5]\\d") String reminderTime,
            Boolean notificationsEnabled) {}

    private final UserRepository users;

    public ProfileController(UserRepository users) {
        this.users = users;
    }

    @GetMapping("/profile")
    public Profile profile(AuthUser user) {
        return Profile.of(users.findById(user.id()).orElseThrow(() -> ApiException.notFound("User")));
    }

    @PatchMapping("/preferences")
    public Profile preferences(AuthUser user, @Valid @RequestBody Preferences p) {
        if (p.timezone() != null) {
            try {
                ZoneId.of(p.timezone());
            } catch (DateTimeException e) {
                throw ApiException.badRequest("VALIDATION_FAILED", "timezone: unknown zone");
            }
        }
        users.updatePreferences(user.id(), p.displayName() == null ? null : p.displayName().trim(), p.avatarId(),
                p.country(), p.locale(), p.timezone(), p.reminderTime() == null ? null : LocalTime.parse(p.reminderTime()),
                p.notificationsEnabled());
        return profile(user);
    }

    /** Account deletion: removes the user and all user-scoped data (cascades); purchases are kept unlinked for audit. */
    @DeleteMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(AuthUser user) {
        users.delete(user.id());
    }
}
