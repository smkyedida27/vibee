package com.puzzlehub.economy;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

/** 7-day login calendar. Missing a day restarts at day 1; claims are idempotent per UTC day. */
@Service
public class DailyRewardService {

    public record Reward(int coins, int gems) {}

    public record Claim(int day, Reward reward, boolean alreadyClaimed, WalletService.Wallet wallet,
                        Instant nextClaimAt, List<Reward> calendar) {}

    static final List<Reward> CALENDAR = List.of(
            new Reward(100, 0), new Reward(150, 0), new Reward(200, 0), new Reward(0, 5),
            new Reward(300, 0), new Reward(400, 0), new Reward(0, 15));

    private final JdbcClient db;
    private final WalletService wallet;
    private final Clock clock;

    public DailyRewardService(JdbcClient db, WalletService wallet, Clock clock) {
        this.db = db;
        this.wallet = wallet;
        this.clock = clock;
    }

    static int nextDay(LocalDate last, int lastDay, LocalDate today) {
        if (last != null && last.equals(today.minusDays(1))) return lastDay % 7 + 1;
        return 1;
    }

    @Transactional
    public Claim claim(UUID userId) {
        LocalDate today = LocalDate.now(clock.withZone(ZoneOffset.UTC));
        Instant next = today.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();
        var state = db.sql("select last_claim_date, cycle_day from daily_rewards where user_id = :u for update")
                .param("u", userId)
                .query((rs, i) -> new Object[]{rs.getObject(1, LocalDate.class), rs.getInt(2)})
                .optional();
        LocalDate last = state.map(s -> (LocalDate) s[0]).orElse(null);
        int lastDay = state.map(s -> (Integer) s[1]).orElse(0);
        if (today.equals(last)) {
            return new Claim(lastDay, CALENDAR.get(lastDay - 1), true, wallet.get(userId), next, CALENDAR);
        }
        int day = nextDay(last, lastDay, today);
        Reward reward = CALENDAR.get(day - 1);
        db.sql("""
                insert into daily_rewards (user_id, last_claim_date, cycle_day) values (:u, :d, :c)
                on conflict (user_id) do update set last_claim_date = excluded.last_claim_date, cycle_day = excluded.cycle_day""")
                .param("u", userId).param("d", today).param("c", day).update();
        String key = "daily-reward:" + today;
        if (reward.coins() > 0) wallet.apply(userId, WalletService.Currency.COINS, reward.coins(), "DAILY_REWARD", key);
        if (reward.gems() > 0) wallet.apply(userId, WalletService.Currency.GEMS, reward.gems(), "DAILY_REWARD", key);
        return new Claim(day, reward, false, wallet.get(userId), next, CALENDAR);
    }
}
