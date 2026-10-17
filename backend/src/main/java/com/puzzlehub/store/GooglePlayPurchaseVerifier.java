package com.puzzlehub.store;

import com.fasterxml.jackson.databind.JsonNode;
import com.google.auth.oauth2.GoogleCredentials;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatusCode;
import org.springframework.web.client.RestClient;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.time.Instant;
import java.util.List;

/**
 * Calls the Android Publisher API v3 with a service account
 * (https://developers.google.com/android-publisher/api-ref/rest/v3/purchases).
 */
public class GooglePlayPurchaseVerifier implements PurchaseVerifier {

    private static final Logger log = LoggerFactory.getLogger(GooglePlayPurchaseVerifier.class);
    private static final String BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/";

    private final String packageName;
    private final GoogleCredentials credentials;
    private final RestClient http;

    public GooglePlayPurchaseVerifier(String packageName, String serviceAccountJson, String serviceAccountJsonPath) {
        boolean inline = serviceAccountJson != null && !serviceAccountJson.isBlank();
        boolean file = serviceAccountJsonPath != null && !serviceAccountJsonPath.isBlank();
        if (packageName == null || packageName.isBlank() || (!inline && !file)) {
            throw new IllegalStateException("Play package name and service account (APP_PLAY_SERVICE_ACCOUNT_JSON) are required");
        }
        this.packageName = packageName;
        try (InputStream in = inline
                ? new java.io.ByteArrayInputStream(serviceAccountJson.getBytes(java.nio.charset.StandardCharsets.UTF_8))
                : new FileInputStream(serviceAccountJsonPath)) {
            this.credentials = GoogleCredentials.fromStream(in)
                    .createScoped(List.of("https://www.googleapis.com/auth/androidpublisher"));
        } catch (IOException e) {
            throw new IllegalStateException("Unable to load Play service account", e);
        }
        // Bounded timeouts: a slow Play API must fail fast rather than pile up request threads.
        var factory = new org.springframework.http.client.SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(java.time.Duration.ofSeconds(3));
        factory.setReadTimeout(java.time.Duration.ofSeconds(8));
        this.http = RestClient.builder().baseUrl(BASE).requestFactory(factory).build();
    }

    @Override
    public Verification verify(Product product, String purchaseToken) {
        try {
            credentials.refreshIfExpired();
            String bearer = "Bearer " + credentials.getAccessToken().getTokenValue();
            if (product.type() == Product.Type.SUBSCRIPTION) {
                JsonNode sub = http.get()
                        .uri("{pkg}/purchases/subscriptionsv2/tokens/{token}", packageName, purchaseToken)
                        .header("Authorization", bearer)
                        .retrieve()
                        .onStatus(HttpStatusCode::is4xxClientError, (req, res) -> {})
                        .body(JsonNode.class);
                if (sub == null || !sub.has("subscriptionState")) return new Verification(false, null, null);
                String state = sub.path("subscriptionState").asText();
                boolean active = state.equals("SUBSCRIPTION_STATE_ACTIVE") || state.equals("SUBSCRIPTION_STATE_IN_GRACE_PERIOD");
                JsonNode line = sub.path("lineItems").path(0);
                boolean matches = line.path("productId").asText().equals(product.productId());
                Instant expiry = line.hasNonNull("expiryTime") ? Instant.parse(line.get("expiryTime").asText()) : null;
                return new Verification(active && matches, sub.path("latestOrderId").asText(null), expiry);
            }
            JsonNode p = http.get()
                    .uri("{pkg}/purchases/products/{product}/tokens/{token}", packageName, product.productId(), purchaseToken)
                    .header("Authorization", bearer)
                    .retrieve()
                    .onStatus(HttpStatusCode::is4xxClientError, (req, res) -> {})
                    .body(JsonNode.class);
            // purchaseState: 0 = purchased, 1 = canceled, 2 = pending
            boolean valid = p != null && p.has("purchaseState") && p.get("purchaseState").asInt() == 0;
            return new Verification(valid, p == null ? null : p.path("orderId").asText(null), null);
        } catch (IOException e) {
            log.error("Google Play verification failed", e);
            throw new IllegalStateException("Purchase verification unavailable", e);
        }
    }
}
