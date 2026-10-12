package com.puzzlehub.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.puzzlehub.common.GlobalExceptionHandler;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.web.authentication.BearerTokenAuthenticationFilter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import javax.crypto.spec.SecretKeySpec;
import java.util.Collection;
import java.util.List;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http, RateLimiter limiter, AppProperties props,
                                            ObjectMapper mapper) throws Exception {
        http.csrf(c -> c.disable())
                .cors(c -> {})
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(a -> a
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers("/api/v1/auth/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/v1/games", "/api/v1/daily-challenge", "/api/v1/store/products").permitAll()
                        .requestMatchers("/actuator/health/**", "/actuator/info", "/actuator/prometheus").permitAll()
                        .requestMatchers("/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html").permitAll()
                        .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                        .requestMatchers("/api/v1/**").authenticated()
                        .anyRequest().denyAll())
                .oauth2ResourceServer(o -> o
                        .jwt(j -> j.jwtAuthenticationConverter(jwtAuthenticationConverter()))
                        .authenticationEntryPoint((req, res, ex) -> writeProblem(mapper, res, HttpStatus.UNAUTHORIZED,
                                "UNAUTHORIZED", "Missing or invalid access token")))
                .exceptionHandling(e -> e
                        .authenticationEntryPoint((req, res, ex) -> writeProblem(mapper, res, HttpStatus.UNAUTHORIZED,
                                "UNAUTHORIZED", "Authentication required"))
                        .accessDeniedHandler((req, res, ex) -> writeProblem(mapper, res, HttpStatus.FORBIDDEN,
                                "FORBIDDEN", "Not allowed")))
                .addFilterAfter(new RateLimitFilter(limiter, props.rateLimit(), mapper), BearerTokenAuthenticationFilter.class);
        return http.build();
    }

    private static void writeProblem(ObjectMapper mapper, jakarta.servlet.http.HttpServletResponse res, HttpStatus status,
                                     String code, String detail) throws java.io.IOException {
        res.setStatus(status.value());
        res.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        mapper.writeValue(res.getOutputStream(), GlobalExceptionHandler.problem(status, code, detail));
    }

    @Bean
    JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(jwt -> {
            Collection<String> roles = jwt.getClaimAsStringList("roles");
            return roles == null ? List.of()
                    : roles.stream().<org.springframework.security.core.GrantedAuthority>map(r -> new SimpleGrantedAuthority("ROLE_" + r)).toList();
        });
        return converter;
    }

    @Bean
    JwtKeys jwtKeys(AppProperties props) {
        return JwtKeys.from(props.jwt());
    }

    @Bean
    JwtDecoder jwtDecoder(JwtKeys keys, AppProperties props) {
        NimbusJwtDecoder decoder = keys.rsa()
                ? NimbusJwtDecoder.withPublicKey(keys.publicKey()).signatureAlgorithm(SignatureAlgorithm.RS256).build()
                : NimbusJwtDecoder.withSecretKey(new SecretKeySpec(keys.hmacSecret(), "HmacSHA256")).macAlgorithm(MacAlgorithm.HS256).build();
        decoder.setJwtValidator(JwtValidators.createDefaultWithIssuer(props.jwt().issuer()));
        return decoder;
    }

    @Bean
    CorsConfigurationSource corsConfigurationSource(AppProperties props) {
        CorsConfiguration cfg = new CorsConfiguration();
        List<String> origins = props.cors() == null || props.cors().allowedOrigins() == null ? List.of() : props.cors().allowedOrigins();
        cfg.setAllowedOrigins(origins);
        cfg.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        cfg.setAllowedHeaders(List.of("Authorization", "Content-Type", "Idempotency-Key", "X-Request-Id"));
        cfg.setExposedHeaders(List.of("X-Request-Id", "Retry-After"));
        cfg.setMaxAge(3600L);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", cfg);
        return source;
    }
}
