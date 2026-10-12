package com.puzzlehub.leaderboard;

import com.puzzlehub.catalog.GameType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Ranked reads with stable tie-breakers: score DESC, duration ASC, submittedAt ASC (then user id for determinism). */
@Service
public class LeaderboardService {

    public enum Scope { GLOBAL, COUNTRY, FRIENDS }

    public record Entry(int rank, UUID userId, String displayName, int avatarId, String country, long score,
                        long durationMs) {}

    public record Page(LocalDate from, LocalDate to, GameType gameType, Scope scope, int page, int size, long total,
                       List<Entry> entries, Entry me) {}

    private final JdbcClient db;

    public LeaderboardService(JdbcClient db) {
        this.db = db;
    }

    @Transactional(readOnly = true)
    public Page daily(UUID me, LocalDate date, GameType gameType, Scope scope, int page, int size) {
        return query(me, date, date, gameType, scope, page, size);
    }

    @Transactional(readOnly = true)
    public Page weekly(UUID me, LocalDate anyDay, Scope scope, int page, int size) {
        LocalDate from = anyDay.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
        return query(me, from, from.plusDays(6), null, scope, page, size);
    }

    private Page query(UUID me, LocalDate from, LocalDate to, GameType gameType, Scope scope, int page, int size) {
        String scopeFilter = switch (scope) {
            case GLOBAL -> "true";
            case COUNTRY -> "u.country = (select country from users where id = :me)";
            case FRIENDS -> "(b.user_id = :me or b.user_id in (select friend_id from friendships where user_id = :me))";
        };
        String ranked = """
                with base as (
                  select l.user_id, sum(l.score) as score, sum(l.duration_ms) as duration_ms, max(l.submitted_at) as submitted_at
                  from leaderboard_entries l
                  where l.challenge_date between :from and :to and (cast(:game as text) is null or l.game_type = :game)
                  group by l.user_id
                ), ranked as (
                  select b.user_id, b.score, b.duration_ms, u.display_name, u.avatar_id, u.country,
                         row_number() over (order by b.score desc, b.duration_ms, b.submitted_at, b.user_id) as rank
                  from base b join users u on u.id = b.user_id
                  where %s
                )
                """.formatted(scopeFilter);
        Map<String, Object> params = new java.util.HashMap<>();
        params.put("from", from);
        params.put("to", to);
        params.put("game", gameType == null ? null : gameType.name());
        params.put("me", me);

        List<Entry> entries = db.sql(ranked + " select * from ranked order by rank limit :limit offset :offset")
                .params(params).param("limit", size).param("offset", (long) page * size)
                .query((rs, i) -> map(rs)).list();
        long total = db.sql(ranked + " select count(*) from ranked").params(params).query(Long.class).single();
        Entry mine = db.sql(ranked + " select * from ranked where user_id = :me").params(params)
                .query((rs, i) -> map(rs)).optional().orElse(null);
        return new Page(from, to, gameType, scope, page, size, total, entries, mine);
    }

    private static Entry map(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new Entry(rs.getInt("rank"), rs.getObject("user_id", UUID.class), rs.getString("display_name"),
                rs.getInt("avatar_id"), rs.getString("country"), rs.getLong("score"), rs.getLong("duration_ms"));
    }
}
