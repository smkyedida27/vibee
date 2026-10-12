package com.puzzlehub.config;

import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;

/** Signing material: RS256 key pair in production, HS256 secret in dev/test. */
public record JwtKeys(byte[] hmacSecret, RSAPrivateKey privateKey, RSAPublicKey publicKey) {

    public boolean rsa() {
        return privateKey != null;
    }

    static JwtKeys from(AppProperties.Jwt cfg) {
        if (notBlank(cfg.privateKey()) && notBlank(cfg.publicKey())) {
            try {
                KeyFactory kf = KeyFactory.getInstance("RSA");
                RSAPrivateKey priv = (RSAPrivateKey) kf.generatePrivate(new PKCS8EncodedKeySpec(decodePem(cfg.privateKey())));
                RSAPublicKey pub = (RSAPublicKey) kf.generatePublic(new X509EncodedKeySpec(decodePem(cfg.publicKey())));
                return new JwtKeys(null, priv, pub);
            } catch (Exception e) {
                throw new IllegalStateException("Invalid RS256 key configuration", e);
            }
        }
        if (!notBlank(cfg.hmacSecret()) || cfg.hmacSecret().getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException("puzzlehub.jwt: configure an RS256 key pair or an HMAC secret of at least 32 bytes");
        }
        return new JwtKeys(cfg.hmacSecret().getBytes(StandardCharsets.UTF_8), null, null);
    }

    private static byte[] decodePem(String value) {
        String b64 = value.replaceAll("-----[A-Z ]+-----", "").replaceAll("\\s", "");
        return Base64.getDecoder().decode(b64);
    }

    private static boolean notBlank(String s) {
        return s != null && !s.isBlank();
    }
}
