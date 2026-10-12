package com.puzzlehub.attempts;

import com.fasterxml.jackson.databind.JsonNode;
import com.puzzlehub.common.ApiException;
import com.puzzlehub.identity.AuthUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/attempts")
public class AttemptController {

    static final String KEY_PATTERN = "[A-Za-z0-9._:-]{8,128}";

    public record CreateAttempt(@NotNull UUID puzzleId, @Pattern(regexp = KEY_PATTERN) String idempotencyKey) {}

    public record SubmitAttempt(@NotNull JsonNode submission, @Min(0) @Max(50) int hintsUsed,
                                @Min(0) @Max(86_400_000) long clientDurationMs) {}

    private final AttemptService service;

    public AttemptController(AttemptService service) {
        this.service = service;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AttemptService.AttemptDto create(AuthUser user, @Valid @RequestBody CreateAttempt body,
                                            @RequestHeader(value = "Idempotency-Key", required = false) String header) {
        String key = body.idempotencyKey() != null ? body.idempotencyKey() : header;
        if (key == null || !key.matches(KEY_PATTERN)) {
            throw ApiException.badRequest("IDEMPOTENCY_KEY_REQUIRED", "Provide an idempotencyKey (8-128 chars)");
        }
        return service.create(user.id(), body.puzzleId(), key);
    }

    @PostMapping("/{id}/submit")
    public AttemptService.SubmitResult submit(AuthUser user, @PathVariable UUID id, @Valid @RequestBody SubmitAttempt body) {
        return service.submit(user.id(), id, body.submission(), body.hintsUsed(), body.clientDurationMs());
    }
}
