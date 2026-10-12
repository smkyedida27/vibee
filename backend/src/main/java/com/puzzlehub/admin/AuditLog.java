package com.puzzlehub.admin;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.UUID;

@Component
public class AuditLog {

    private final JdbcClient db;
    private final ObjectMapper mapper;

    public AuditLog(JdbcClient db, ObjectMapper mapper) {
        this.db = db;
        this.mapper = mapper;
    }

    public void record(UUID actor, String action, String target, Map<String, Object> details) {
        try {
            db.sql("insert into audit_log (actor_id, action, target, details) values (:a, :ac, :t, cast(:d as jsonb))")
                    .param("a", actor).param("ac", action).param("t", target)
                    .param("d", mapper.writeValueAsString(details)).update();
        } catch (JsonProcessingException e) {
            throw new IllegalStateException(e);
        }
    }
}
