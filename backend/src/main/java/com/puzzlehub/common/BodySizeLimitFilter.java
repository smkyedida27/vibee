package com.puzzlehub.common;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/** Rejects oversized request bodies before they reach JSON parsing. Progress snapshots are the largest payload. */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class BodySizeLimitFilter extends OncePerRequestFilter {

    static final long MAX_BYTES = 256 * 1024;
    private final ObjectMapper mapper;

    public BodySizeLimitFilter(ObjectMapper mapper) {
        this.mapper = mapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        long len = request.getContentLengthLong();
        if (len > MAX_BYTES) {
            response.setStatus(HttpStatus.PAYLOAD_TOO_LARGE.value());
            response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
            mapper.writeValue(response.getOutputStream(), GlobalExceptionHandler.problem(HttpStatus.PAYLOAD_TOO_LARGE,
                    "PAYLOAD_TOO_LARGE", "Request body exceeds " + MAX_BYTES + " bytes"));
            return;
        }
        chain.doFilter(len < 0 ? new LimitedRequest(request) : request, response);
    }

    /** Caps bodies sent without Content-Length (chunked). */
    private static final class LimitedRequest extends jakarta.servlet.http.HttpServletRequestWrapper {
        LimitedRequest(HttpServletRequest request) { super(request); }

        @Override
        public jakarta.servlet.ServletInputStream getInputStream() throws IOException {
            jakarta.servlet.ServletInputStream in = super.getInputStream();
            return new jakarta.servlet.ServletInputStream() {
                private long read;
                @Override public boolean isFinished() { return in.isFinished(); }
                @Override public boolean isReady() { return in.isReady(); }
                @Override public void setReadListener(jakarta.servlet.ReadListener l) { in.setReadListener(l); }
                @Override public int read() throws IOException {
                    int b = in.read();
                    if (b >= 0 && ++read > MAX_BYTES) throw new IOException("Request body too large");
                    return b;
                }
            };
        }
    }
}
