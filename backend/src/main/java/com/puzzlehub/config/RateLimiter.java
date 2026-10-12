package com.puzzlehub.config;

/** Abstraction so the in-memory implementation can be swapped for a Redis-backed one when running many instances. */
public interface RateLimiter {

    /** @return true if a token was consumed for {@code key} within the per-minute {@code limit}. */
    boolean tryConsume(String key, int limitPerMinute);
}
