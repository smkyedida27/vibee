package com.puzzlehub.config;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import org.springframework.stereotype.Component;

import java.time.Duration;

/** Per-instance token buckets (bucket4j) with bounded memory. */
@Component
public class InMemoryRateLimiter implements RateLimiter {

    private final Cache<String, Bucket> buckets = Caffeine.newBuilder()
            .maximumSize(200_000)
            .expireAfterAccess(Duration.ofMinutes(10))
            .build();

    @Override
    public boolean tryConsume(String key, int limitPerMinute) {
        Bucket bucket = buckets.get(key + "|" + limitPerMinute, k -> Bucket.builder()
                .addLimit(Bandwidth.builder().capacity(limitPerMinute).refillGreedy(limitPerMinute, Duration.ofMinutes(1)).build())
                .build());
        return bucket.tryConsume(1);
    }
}
