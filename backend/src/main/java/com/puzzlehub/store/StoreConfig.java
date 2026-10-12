package com.puzzlehub.store;

import com.puzzlehub.config.AppProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;

import java.time.Clock;

@Configuration
public class StoreConfig {

    @Bean
    PurchaseVerifier purchaseVerifier(AppProperties props, Environment env, Clock clock) {
        if ("fake".equals(props.play().mode())) {
            if (env.acceptsProfiles(Profiles.of("prod"))) {
                throw new IllegalStateException("Fake purchase verification is not allowed in prod");
            }
            return new FakePurchaseVerifier(clock);
        }
        return new GooglePlayPurchaseVerifier(props.play().packageName(), props.play().serviceAccountJson(),
                props.play().serviceAccountJsonPath());
    }
}
