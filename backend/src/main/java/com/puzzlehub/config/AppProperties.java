package com.puzzlehub.config;

import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;
import java.util.List;

@Validated
@ConfigurationProperties(prefix = "puzzlehub")
public record AppProperties(String environment, Jwt jwt, Firebase firebase, Play play, Cors cors, RateLimit rateLimit, Daily daily) {

    /**
     * Either {@code hmacSecret} (HS256, dev/test) or {@code privateKey}+{@code publicKey}
     * (base64 PKCS#8 / X.509 DER, RS256, production) must be set.
     */
    public record Jwt(@NotBlank String issuer, String hmacSecret, String privateKey, String publicKey,
                      Duration accessTtl, Duration refreshTtl) {}

    /** mode = google | fake. */
    public record Firebase(String mode, String projectId) {}

    /** mode = google | fake. */
    public record Play(String mode, String packageName, String serviceAccountJson, String serviceAccountJsonPath) {}

    public record Cors(List<String> allowedOrigins) {}

    public record RateLimit(int authPerMinute, int submitPerMinute, int leaderboardPerMinute) {}

    public record Daily(int daysAhead, boolean generateOnStartup) {}
}
