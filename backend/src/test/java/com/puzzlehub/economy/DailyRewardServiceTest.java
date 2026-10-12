package com.puzzlehub.economy;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;

class DailyRewardServiceTest {

    static final LocalDate TODAY = LocalDate.of(2026, 10, 11);

    @Test
    void cycleAdvancesWrapsAndResets() {
        assertThat(DailyRewardService.nextDay(null, 0, TODAY)).isEqualTo(1);
        assertThat(DailyRewardService.nextDay(TODAY.minusDays(1), 3, TODAY)).isEqualTo(4);
        assertThat(DailyRewardService.nextDay(TODAY.minusDays(1), 7, TODAY)).isEqualTo(1);
        assertThat(DailyRewardService.nextDay(TODAY.minusDays(2), 5, TODAY)).isEqualTo(1);
    }

    @Test
    void calendarHasSevenDays() {
        assertThat(DailyRewardService.CALENDAR).hasSize(7);
    }
}
