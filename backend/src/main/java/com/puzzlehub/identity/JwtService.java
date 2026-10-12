package com.puzzlehub.identity;

import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.JWSSigner;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import com.puzzlehub.config.AppProperties;
import com.puzzlehub.config.JwtKeys;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.UUID;

@Service
public class JwtService {

    private final JwtKeys keys;
    private final AppProperties.Jwt cfg;
    private final Clock clock;

    public JwtService(JwtKeys keys, AppProperties props, Clock clock) {
        this.keys = keys;
        this.cfg = props.jwt();
        this.clock = clock;
    }

    public String issueAccessToken(UUID userId, List<String> roles) {
        Instant now = clock.instant();
        JWTClaimsSet claims = new JWTClaimsSet.Builder()
                .issuer(cfg.issuer())
                .subject(userId.toString())
                .issueTime(Date.from(now))
                .expirationTime(Date.from(now.plus(cfg.accessTtl())))
                .jwtID(UUID.randomUUID().toString())
                .claim("roles", roles)
                .build();
        try {
            JWSSigner signer = keys.rsa() ? new RSASSASigner(keys.privateKey()) : new MACSigner(keys.hmacSecret());
            SignedJWT jwt = new SignedJWT(new JWSHeader(keys.rsa() ? JWSAlgorithm.RS256 : JWSAlgorithm.HS256), claims);
            jwt.sign(signer);
            return jwt.serialize();
        } catch (JOSEException e) {
            throw new IllegalStateException("Unable to sign token", e);
        }
    }

    public long accessTtlSeconds() {
        return cfg.accessTtl().toSeconds();
    }
}
