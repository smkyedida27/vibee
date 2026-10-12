package com.puzzlehub.identity;

import com.puzzlehub.config.AppProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;

@Configuration
public class IdentityConfig {

    @Bean
    FirebaseTokenVerifier firebaseTokenVerifier(AppProperties props, Environment env) {
        if ("fake".equals(props.firebase().mode())) {
            if (env.acceptsProfiles(Profiles.of("prod"))) {
                throw new IllegalStateException("Fake Firebase verification is not allowed in prod");
            }
            return new FakeFirebaseTokenVerifier();
        }
        return new GoogleFirebaseTokenVerifier(props.firebase().projectId());
    }
}
