package com.puzzlehub.it;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Map;

/** Minimal JSON HTTP client for black-box API tests. */
final class Api {

    record Res(int status, JsonNode body, Map<String, java.util.List<String>> headers) {
        String header(String name) {
            return headers.entrySet().stream().filter(e -> e.getKey().equalsIgnoreCase(name))
                    .map(e -> e.getValue().getFirst()).findFirst().orElse(null);
        }
    }

    private static final ObjectMapper M = new ObjectMapper();
    private final HttpClient http = HttpClient.newHttpClient();
    private final String base;

    Api(int port) {
        this.base = "http://localhost:" + port;
    }

    Res get(String path, String token) {
        return send("GET", path, null, token);
    }

    Res post(String path, Object body, String token) {
        return send("POST", path, body, token);
    }

    Res put(String path, Object body, String token) {
        return send("PUT", path, body, token);
    }

    Res patch(String path, Object body, String token) {
        return send("PATCH", path, body, token);
    }

    Res delete(String path, String token) {
        return send("DELETE", path, null, token);
    }

    Res raw(String method, String path, String body, String token) {
        try {
            HttpRequest.Builder b = HttpRequest.newBuilder(URI.create(base + path))
                    .header("Content-Type", "application/json")
                    .header("X-Request-Id", "it-req-1")
                    .method(method, body == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(body));
            if (token != null) b.header("Authorization", "Bearer " + token);
            HttpResponse<String> r = http.send(b.build(), HttpResponse.BodyHandlers.ofString());
            JsonNode node = r.body() == null || r.body().isBlank() ? M.nullNode() : M.readTree(r.body());
            return new Res(r.statusCode(), node, r.headers().map());
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private Res send(String method, String path, Object body, String token) {
        try {
            return raw(method, path, body == null ? null : M.writeValueAsString(body), token);
        } catch (com.fasterxml.jackson.core.JsonProcessingException e) {
            throw new RuntimeException(e);
        }
    }
}
