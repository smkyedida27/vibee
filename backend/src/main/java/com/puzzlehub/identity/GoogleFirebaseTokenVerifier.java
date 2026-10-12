package com.puzzlehub.identity;

import com.puzzlehub.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

/** Validates Firebase ID tokens against Google's published signing keys (cached by Nimbus). */
public class GoogleFirebaseTokenVerifier implements FirebaseTokenVerifier {

    private static final String JWKS =
            "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

    private final NimbusJwtDecoder decoder;

    public GoogleFirebaseTokenVerifier(String projectId) {
        if (projectId == null || projectId.isBlank()) {
            throw new IllegalStateException("puzzlehub.firebase.project-id is required in google mode");
        }
        decoder = NimbusJwtDecoder.withJwkSetUri(JWKS).jwsAlgorithm(SignatureAlgorithm.RS256).build();
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
                JwtValidators.createDefaultWithIssuer("https://securetoken.google.com/" + projectId),
                jwt -> jwt.getAudience() != null && jwt.getAudience().contains(projectId)
                        ? OAuth2TokenValidatorResult.success()
                        : OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token", "bad audience", null))));
    }

    @Override
    public String verify(String idToken) {
        try {
            Jwt jwt = decoder.decode(idToken);
            if (jwt.getSubject() == null || jwt.getSubject().isBlank()) throw new JwtException("missing sub");
            return jwt.getSubject();
        } catch (JwtException e) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_ID_TOKEN", "Firebase ID token is invalid");
        }
    }
}
