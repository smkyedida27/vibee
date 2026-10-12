package com.puzzlehub.daily;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.puzzlehub.catalog.Difficulty;
import com.puzzlehub.catalog.GameType;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class PuzzleRepository {

    /** A daily slot joined with its puzzle. */
    public record DailyPuzzle(LocalDate date, Puzzle puzzle) {}

    private final JdbcClient jdbc;
    private final ObjectMapper mapper;
    private final RowMapper<Puzzle> puzzleMapper;

    public PuzzleRepository(JdbcClient jdbc, ObjectMapper mapper) {
        this.jdbc = jdbc;
        this.mapper = mapper;
        this.puzzleMapper = (rs, i) -> {
            try {
                return new Puzzle(rs.getObject("id", UUID.class), GameType.valueOf(rs.getString("game_type")),
                        Difficulty.valueOf(rs.getString("difficulty")), rs.getInt("rules_version"),
                        rs.getInt("content_version"), rs.getString("checksum"), rs.getString("status"),
                        mapper.readTree(rs.getString("content")));
            } catch (JsonProcessingException e) {
                throw new IllegalStateException("Corrupt puzzle content", e);
            }
        };
    }

    public void insert(Puzzle p) {
        try {
            jdbc.sql("""
                    insert into puzzles (id, game_type, difficulty, rules_version, content_version, content, checksum, status)
                    values (:id, :type, :diff, :rules, :cv, cast(:content as jsonb), :checksum, :status)""")
                    .param("id", p.id()).param("type", p.gameType().name()).param("diff", p.difficulty().name())
                    .param("rules", p.rulesVersion()).param("cv", p.contentVersion())
                    .param("content", mapper.writeValueAsString(p.content())).param("checksum", p.checksum())
                    .param("status", p.status())
                    .update();
        } catch (JsonProcessingException e) {
            throw new IllegalStateException(e);
        }
    }

    public void assignDaily(LocalDate date, GameType type, UUID puzzleId) {
        jdbc.sql("""
                insert into daily_challenges (challenge_date, game_type, puzzle_id, rules_version)
                values (:d, :t, :p, :r)
                on conflict (challenge_date, game_type) do update set puzzle_id = excluded.puzzle_id""")
                .param("d", date).param("t", type.name()).param("p", puzzleId).param("r", GameType.RULES_VERSION)
                .update();
    }

    public List<GameType> existingTypes(LocalDate date) {
        return jdbc.sql("select game_type from daily_challenges where challenge_date = :d").param("d", date)
                .query((rs, i) -> GameType.valueOf(rs.getString(1))).list();
    }

    public List<Puzzle> dailyPuzzles(LocalDate date) {
        return jdbc.sql("""
                select p.* from daily_challenges d join puzzles p on p.id = d.puzzle_id
                where d.challenge_date = :d order by array_position(array['CONNECT','QUEENS','SUDOKU','LADDER','MERGE'], p.game_type)""")
                .param("d", date).query(puzzleMapper).list();
    }

    public Optional<Puzzle> findById(UUID id) {
        return jdbc.sql("select * from puzzles where id = :id").param("id", id).query(puzzleMapper).optional();
    }

    /** The daily date a puzzle is (or was) assigned to; also checks history so replaced puzzles still resolve. */
    public Optional<LocalDate> dailyDateOf(UUID puzzleId) {
        return jdbc.sql("select challenge_date from daily_challenges where puzzle_id = :id").param("id", puzzleId)
                .query((rs, i) -> rs.getObject(1, LocalDate.class)).optional();
    }

    public Optional<Puzzle> dailyPuzzle(LocalDate date, GameType type) {
        return jdbc.sql("""
                select p.* from daily_challenges d join puzzles p on p.id = d.puzzle_id
                where d.challenge_date = :d and d.game_type = :t""")
                .param("d", date).param("t", type.name()).query(puzzleMapper).optional();
    }

    public int setStatus(UUID id, String status) {
        return jdbc.sql("update puzzles set status = :s where id = :id").param("s", status).param("id", id).update();
    }

    /** Transaction-scoped advisory lock so only one instance generates a given date. */
    public void lockDate(LocalDate date) {
        jdbc.sql("select pg_advisory_xact_lock(hashtext(:k))").param("k", "daily:" + date).query(Object.class).single();
    }
}
