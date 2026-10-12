package com.puzzlehub.progress;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.puzzlehub.common.ConflictWithBodyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

/** Opaque, versioned progress snapshot with optimistic concurrency. The client merges on 409. */
@Service
public class ProgressService {

    public record Snapshot(long version, JsonNode data, Instant updatedAt) {}

    private final JdbcClient db;
    private final ObjectMapper mapper;
    private final Clock clock;

    public ProgressService(JdbcClient db, ObjectMapper mapper, Clock clock) {
        this.db = db;
        this.mapper = mapper;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public Snapshot get(UUID userId) {
        return db.sql("select version, data, updated_at from user_progress where user_id = :u").param("u", userId)
                .query((rs, i) -> new Snapshot(rs.getLong(1), read(rs.getString(2)), rs.getTimestamp(3).toInstant()))
                .optional()
                .orElse(new Snapshot(0, mapper.createObjectNode(), null));
    }

    /** {@code expectedVersion} must equal the stored version (0 when none). Returns the new snapshot (version + 1). */
    @Transactional
    public Snapshot put(UUID userId, long expectedVersion, JsonNode data) {
        Instant now = clock.instant();
        String json;
        try {
            json = mapper.writeValueAsString(data);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException(e);
        }
        int updated;
        if (expectedVersion == 0) {
            updated = db.sql("""
                    insert into user_progress (user_id, version, data, updated_at) values (:u, 1, cast(:d as jsonb), :t)
                    on conflict (user_id) do nothing""")
                    .param("u", userId).param("d", json).param("t", Timestamp.from(now)).update();
        } else {
            updated = db.sql("""
                    update user_progress set version = version + 1, data = cast(:d as jsonb), updated_at = :t
                    where user_id = :u and version = :v""")
                    .param("u", userId).param("d", json).param("t", Timestamp.from(now)).param("v", expectedVersion)
                    .update();
        }
        if (updated == 0) throw new ConflictWithBodyException(get(userId));
        return new Snapshot(expectedVersion + 1, data, now);
    }

    private JsonNode read(String json) {
        try {
            return mapper.readTree(json);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException(e);
        }
    }
}
