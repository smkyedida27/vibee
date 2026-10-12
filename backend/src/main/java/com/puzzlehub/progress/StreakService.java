package com.puzzlehub.progress;

import com.puzzlehub.catalog.GameType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

/**
 * Daily streak: a day qualifies when the player solves at least one of that day's challenges on that UTC day.
 * Solving an older daily later (catch-up) never extends a streak.
 */
@Service
public class StreakService {

    public record Streak(int currentStreak, int bestStreak, LocalDate lastQualifyingDate, List<GameType> todayCompleted) {}

    record State(int current, int best, LocalDate last) {}

    private final JdbcClient db;
    private final Clock clock;

    public StreakService(JdbcClient db, Clock clock) {
        this.db = db;
        this.clock = clock;
    }

    LocalDate today() {
        return LocalDate.now(clock.withZone(ZoneOffset.UTC));
    }

    /** Pure transition function, unit-tested. */
    static State transition(State s, LocalDate challengeDate, LocalDate today) {
        if (!challengeDate.equals(today)) return s;
        if (s.last() != null && !s.last().isBefore(today)) return s;
        int current = s.last() != null && s.last().equals(today.minusDays(1)) ? s.current() + 1 : 1;
        return new State(current, Math.max(s.best(), current), today);
    }

    /** What the player sees: a streak whose last day is before yesterday has lapsed. */
    static int visibleCurrent(State s, LocalDate today) {
        return s.last() != null && !s.last().isBefore(today.minusDays(1)) ? s.current() : 0;
    }

    @Transactional
    public void recordQualifying(UUID userId, LocalDate challengeDate) {
        db.sql("insert into streaks (user_id) values (:u) on conflict do nothing").param("u", userId).update();
        State s = load(userId);
        State next = transition(s, challengeDate, today());
        if (next != s) {
            db.sql("update streaks set current_streak = :c, best_streak = :b, last_qualifying_date = :l where user_id = :u")
                    .param("c", next.current()).param("b", next.best()).param("l", next.last()).param("u", userId)
                    .update();
        }
    }

    private State load(UUID userId) {
        return db.sql("select current_streak, best_streak, last_qualifying_date from streaks where user_id = :u for update")
                .param("u", userId)
                .query((rs, i) -> new State(rs.getInt(1), rs.getInt(2), rs.getObject(3, LocalDate.class)))
                .optional().orElse(new State(0, 0, null));
    }

    @Transactional(readOnly = true)
    public Streak get(UUID userId) {
        LocalDate today = today();
        State s = db.sql("select current_streak, best_streak, last_qualifying_date from streaks where user_id = :u")
                .param("u", userId)
                .query((rs, i) -> new State(rs.getInt(1), rs.getInt(2), rs.getObject(3, LocalDate.class)))
                .optional().orElse(new State(0, 0, null));
        List<GameType> completed = db.sql("""
                select distinct dc.game_type from attempts a
                join daily_challenges dc on dc.puzzle_id = a.puzzle_id
                where a.user_id = :u and dc.challenge_date = :d and a.result = 'SOLVED'
                order by dc.game_type""")
                .param("u", userId).param("d", today)
                .query((rs, i) -> GameType.valueOf(rs.getString(1))).list();
        return new Streak(visibleCurrent(s, today), s.best(), s.last(), completed);
    }
}
