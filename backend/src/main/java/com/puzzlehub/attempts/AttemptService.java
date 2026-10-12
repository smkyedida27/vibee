package com.puzzlehub.attempts;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.puzzlehub.catalog.GameType;
import com.puzzlehub.common.ApiException;
import com.puzzlehub.daily.Puzzle;
import com.puzzlehub.daily.PuzzleRepository;
import com.puzzlehub.progress.StreakService;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

@Service
public class AttemptService {

    public record AttemptDto(UUID attemptId, UUID puzzleId, Instant startedAt) {}

    public record SubmitResult(Result result, int score, long durationMs, boolean counted, Integer rank) {}

    private record AttemptRow(UUID id, UUID userId, UUID puzzleId, Instant startedAt, Instant submittedAt,
                              String result, Integer score, Long durationMs, boolean counted) {}

    private final JdbcClient db;
    private final PuzzleRepository puzzles;
    private final SubmissionValidator validator;
    private final StreakService streaks;
    private final ObjectMapper mapper;
    private final MeterRegistry metrics;
    private final Clock clock;

    public AttemptService(JdbcClient db, PuzzleRepository puzzles, SubmissionValidator validator, StreakService streaks,
                          ObjectMapper mapper, MeterRegistry metrics, Clock clock) {
        this.db = db;
        this.puzzles = puzzles;
        this.validator = validator;
        this.streaks = streaks;
        this.mapper = mapper;
        this.metrics = metrics;
        this.clock = clock;
    }

    /** Idempotent per (user, idempotencyKey): replays return the original attempt. */
    @Transactional
    public AttemptDto create(UUID userId, UUID puzzleId, String idempotencyKey) {
        Puzzle puzzle = puzzles.findById(puzzleId).orElseThrow(() -> ApiException.notFound("Puzzle"));
        if (!"ACTIVE".equals(puzzle.status())) {
            throw new ApiException(HttpStatus.GONE, "PUZZLE_DISABLED", "This puzzle has been withdrawn");
        }
        if (puzzles.dailyDateOf(puzzleId).isEmpty()) throw ApiException.notFound("Puzzle");
        UUID id = UUID.randomUUID();
        Instant now = clock.instant();
        db.sql("""
                insert into attempts (id, user_id, puzzle_id, idempotency_key, started_at)
                values (:id, :u, :p, :k, :t) on conflict (user_id, idempotency_key) do nothing""")
                .param("id", id).param("u", userId).param("p", puzzleId).param("k", idempotencyKey)
                .param("t", Timestamp.from(now))
                .update();
        AttemptRow row = db.sql("select * from attempts where user_id = :u and idempotency_key = :k")
                .param("u", userId).param("k", idempotencyKey).query(this::map).single();
        if (!row.puzzleId().equals(puzzleId)) {
            throw ApiException.conflict("IDEMPOTENCY_KEY_REUSED", "Idempotency key was used for a different puzzle");
        }
        return new AttemptDto(row.id(), row.puzzleId(), row.startedAt());
    }

    @Transactional
    public SubmitResult submit(UUID userId, UUID attemptId, JsonNode submission, int hintsUsed, long clientDurationMs) {
        AttemptRow attempt = db.sql("select * from attempts where id = :id for update").param("id", attemptId)
                .query(this::map).optional()
                .filter(a -> a.userId().equals(userId)) // other users' attempts are indistinguishable from missing ones
                .orElseThrow(() -> ApiException.notFound("Attempt"));
        if (attempt.submittedAt() != null) {
            return new SubmitResult(Result.valueOf(attempt.result()), attempt.score(), attempt.durationMs(),
                    attempt.counted(), attempt.counted() ? rankOf(userId, attempt.puzzleId()).orElse(null) : null);
        }
        Puzzle puzzle = puzzles.findById(attempt.puzzleId()).orElseThrow();
        LocalDate date = puzzles.dailyDateOf(puzzle.id())
                .orElseThrow(() -> new ApiException(HttpStatus.GONE, "PUZZLE_DISABLED", "This puzzle has been withdrawn"));

        Instant now = clock.instant();
        long serverMs = Math.max(0, now.toEpochMilli() - attempt.startedAt().toEpochMilli());
        long durationMs = Math.max(serverMs, Math.max(0, clientDurationMs));
        Evaluation eval = validator.evaluate(puzzle, submission);
        int par = puzzle.gameType() == GameType.LADDER ? puzzle.content().path("par").asInt() : 0;
        int score = Scoring.score(puzzle.gameType(), eval, hintsUsed, durationMs / 1000, par);

        boolean counted = eval.result() != Result.INVALID && "ACTIVE".equals(puzzle.status())
                && !db.sql("select exists(select 1 from attempts where user_id = :u and puzzle_id = :p and counted)")
                .param("u", userId).param("p", puzzle.id()).query(Boolean.class).single();
        db.sql("""
                update attempts set submitted_at = :t, result = :r, score = :s, duration_ms = :d, hints_used = :h,
                  submission = cast(:sub as jsonb), counted = :c where id = :id""")
                .param("t", Timestamp.from(now)).param("r", eval.result().name()).param("s", score)
                .param("d", durationMs).param("h", hintsUsed).param("sub", json(submission)).param("c", counted)
                .param("id", attemptId)
                .update();

        boolean ranked = counted && (eval.result() == Result.SOLVED || puzzle.gameType() == GameType.MERGE);
        if (ranked) {
            db.sql("""
                    insert into leaderboard_entries (challenge_date, game_type, user_id, attempt_id, score, duration_ms, submitted_at)
                    values (:d, :g, :u, :a, :s, :ms, :t) on conflict do nothing""")
                    .param("d", date).param("g", puzzle.gameType().name()).param("u", userId).param("a", attemptId)
                    .param("s", score).param("ms", durationMs).param("t", Timestamp.from(now))
                    .update();
        }
        if (eval.result() == Result.SOLVED) streaks.recordQualifying(userId, date);
        metrics.counter("puzzlehub.attempts.submitted", "game", puzzle.gameType().name(), "result", eval.result().name())
                .increment();
        return new SubmitResult(eval.result(), score, durationMs, counted, ranked ? rankOf(userId, puzzle.id()).orElse(null) : null);
    }

    private Optional<Integer> rankOf(UUID userId, UUID puzzleId) {
        return db.sql("""
                select r.rank from (
                  select l.user_id, row_number() over (order by l.score desc, l.duration_ms, l.submitted_at) as rank
                  from leaderboard_entries l
                  join daily_challenges dc on dc.challenge_date = l.challenge_date and dc.game_type = l.game_type
                  where dc.puzzle_id = :p) r
                where r.user_id = :u""")
                .param("p", puzzleId).param("u", userId).query(Integer.class).optional();
    }

    private String json(JsonNode node) {
        try {
            return mapper.writeValueAsString(node);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException(e);
        }
    }

    private AttemptRow map(java.sql.ResultSet rs, int i) throws java.sql.SQLException {
        Timestamp sub = rs.getTimestamp("submitted_at");
        return new AttemptRow(rs.getObject("id", UUID.class), rs.getObject("user_id", UUID.class),
                rs.getObject("puzzle_id", UUID.class), rs.getTimestamp("started_at").toInstant(),
                sub == null ? null : sub.toInstant(), rs.getString("result"),
                (Integer) rs.getObject("score"), (Long) rs.getObject("duration_ms"), rs.getBoolean("counted"));
    }
}
