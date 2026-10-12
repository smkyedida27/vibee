package com.puzzlehub.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.puzzlehub.common.GlobalExceptionHandler;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/** Applies rate limits to abuse-sensitive endpoints. Registered in the security chain after authentication. */
public class RateLimitFilter extends OncePerRequestFilter {

    private final RateLimiter limiter;
    private final AppProperties.RateLimit limits;
    private final ObjectMapper mapper;

    public RateLimitFilter(RateLimiter limiter, AppProperties.RateLimit limits, ObjectMapper mapper) {
        this.limiter = limiter;
        this.limits = limits;
        this.mapper = mapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String path = request.getRequestURI();
        String bucket = null;
        int limit = 0;
        if (path.startsWith("/api/v1/auth/")) {
            bucket = "auth";
            limit = limits.authPerMinute();
        } else if (path.startsWith("/api/v1/attempts") && "POST".equals(request.getMethod())) {
            bucket = "attempts";
            limit = limits.submitPerMinute();
        } else if (path.startsWith("/api/v1/leaderboards")) {
            bucket = "leaderboards";
            limit = limits.leaderboardPerMinute();
        }
        if (bucket != null && !limiter.tryConsume(bucket + ":" + principalKey(request), limit)) {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setHeader("Retry-After", "60");
            response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
            mapper.writeValue(response.getOutputStream(), GlobalExceptionHandler.problem(HttpStatus.TOO_MANY_REQUESTS,
                    "RATE_LIMITED", "Too many requests, retry later"));
            return;
        }
        chain.doFilter(request, response);
    }

    private static String principalKey(HttpServletRequest request) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && auth.getName() != null && !"anonymousUser".equals(auth.getName())) {
            return "u:" + auth.getName();
        }
        // Behind a load balancer, server.forward-headers-strategy=native makes getRemoteAddr() the client IP.
        return "ip:" + request.getRemoteAddr();
    }
}
