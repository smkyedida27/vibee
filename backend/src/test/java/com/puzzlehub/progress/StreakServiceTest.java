package com.puzzlehub.progress;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;

class StreakServiceTest {

    static final LocalDate TODAY = LocalDate.of(2026, 10, 11);

    @Test
    void firstQualifyingDayStartsAtOne() {
        var s = StreakService.transition(new StreakService.State(0, 0, null), TODAY, TODAY);
        assertThat(s).isEqualTo(new StreakService.State(1, 1, TODAY));
    }

    @Test
    void consecutiveDayExtends() {
        var s = StreakService.transition(new StreakService.State(4, 6, TODAY.minusDays(1)), TODAY, TODAY);
        assertThat(s).isEqualTo(new StreakService.State(5, 6, TODAY));
    }

    @Test
    void gapResetsButKeepsBest() {
        var s = StreakService.transition(new StreakService.State(9, 9, TODAY.minusDays(3)), TODAY, TODAY);
        assertThat(s).isEqualTo(new StreakService.State(1, 9, TODAY));
    }

    @Test
    void sameDayAndCatchUpAreNoOps() {
        var s = new StreakService.State(3, 3, TODAY);
        assertThat(StreakService.transition(s, TODAY, TODAY)).isSameAs(s);
        var y = new StreakService.State(3, 3, TODAY.minusDays(1));
        assertThat(StreakService.transition(y, TODAY.minusDays(2), TODAY)).isSameAs(y);
    }

    @Test
    void lapsedStreakIsShownAsZero() {
        assertThat(StreakService.visibleCurrent(new StreakService.State(5, 5, TODAY.minusDays(1)), TODAY)).isEqualTo(5);
        assertThat(StreakService.visibleCurrent(new StreakService.State(5, 5, TODAY.minusDays(2)), TODAY)).isZero();
    }
}
