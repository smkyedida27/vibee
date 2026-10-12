package com.puzzlehub.daily;

import com.puzzlehub.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;

/** Keeps today plus the next N days generated ahead of the 00:00 UTC reset. */
@Component
public class DailyScheduler {

    private static final Logger log = LoggerFactory.getLogger(DailyScheduler.class);

    private final DailyChallengeService service;
    private final AppProperties props;

    public DailyScheduler(DailyChallengeService service, AppProperties props) {
        this.service = service;
        this.props = props;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void onStartup() {
        if (props.daily().generateOnStartup()) ensureUpcoming();
    }

    @Scheduled(cron = "0 7 * * * *", zone = "UTC")
    public void ensureUpcoming() {
        LocalDate today = service.today();
        for (int i = 0; i <= props.daily().daysAhead(); i++) {
            try {
                service.ensure(today.plusDays(i));
            } catch (RuntimeException e) {
                // Surfaced via logs/alerts; the next run retries. A missing *today* is a SEV-1 per the runbook.
                log.error("Failed to generate daily challenge for {}", today.plusDays(i), e);
            }
        }
        verifyToday(today);
    }

    /** CloudWatch alarms on the literal DAILY_CHALLENGE_MISSING (runbook SEV-1). */
    void verifyToday(LocalDate today) {
        try {
            int published = service.challenge(today).size();
            if (published < com.puzzlehub.catalog.GameType.values().length) {
                log.error("DAILY_CHALLENGE_MISSING date={} published={}", today, published);
            }
        } catch (RuntimeException e) {
            log.error("DAILY_CHALLENGE_MISSING date={} error={}", today, e.toString());
        }
    }
}
