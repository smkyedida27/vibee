package com.puzzlehub.progress;

import com.fasterxml.jackson.databind.JsonNode;
import com.puzzlehub.catalog.GameType;
import com.puzzlehub.identity.AuthUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/me")
public class ProgressController {

    public record PutProgress(@Min(0) long version, @NotNull JsonNode data) {}

    public record GameStats(GameType gameType, int played, int solved, Integer bestScore, Long avgDurationMs) {}

    private final ProgressService progress;
    private final StreakService streaks;
    private final JdbcClient db;

    public ProgressController(ProgressService progress, StreakService streaks, JdbcClient db) {
        this.progress = progress;
        this.streaks = streaks;
        this.db = db;
    }

    @GetMapping("/progress")
    public ProgressService.Snapshot get(AuthUser user) {
        return progress.get(user.id());
    }

    @PutMapping("/progress")
    public ProgressService.Snapshot put(AuthUser user, @Valid @RequestBody PutProgress body) {
        return progress.put(user.id(), body.version(), body.data());
    }

    @GetMapping("/streak")
    public StreakService.Streak streak(AuthUser user) {
        return streaks.get(user.id());
    }

    @GetMapping("/stats")
    public List<GameStats> stats(AuthUser user) {
        List<GameStats> rows = db.sql("""
                select p.game_type,
                       count(*) as played,
                       count(*) filter (where a.result = 'SOLVED') as solved,
                       max(a.score) filter (where a.result = 'SOLVED') as best,
                       cast(avg(a.duration_ms) filter (where a.result = 'SOLVED') as bigint) as avg_ms
                from attempts a join puzzles p on p.id = a.puzzle_id
                where a.user_id = :u and a.counted
                group by p.game_type""")
                .param("u", user.id())
                .query((rs, i) -> new GameStats(GameType.valueOf(rs.getString(1)), rs.getInt(2), rs.getInt(3),
                        (Integer) rs.getObject(4), (Long) rs.getObject(5)))
                .list();
        return java.util.Arrays.stream(GameType.values())
                .map(g -> rows.stream().filter(r -> r.gameType() == g).findFirst()
                        .orElse(new GameStats(g, 0, 0, null, null)))
                .toList();
    }
}
