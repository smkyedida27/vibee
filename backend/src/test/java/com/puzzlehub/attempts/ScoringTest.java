package com.puzzlehub.attempts;

import com.puzzlehub.catalog.GameType;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ScoringTest {

    private static Evaluation solved(int mistakes, int steps) {
        return new Evaluation(Result.SOLVED, mistakes, steps, 0);
    }

    @Test
    void connect() {
        assertThat(Scoring.score(GameType.CONNECT, solved(1, 0), 1, 40, 0)).isEqualTo(1000 - 150 - 100 - 10);
    }

    @Test
    void queens() {
        assertThat(Scoring.score(GameType.QUEENS, solved(0, 0), 0, 61, 0)).isEqualTo(1000 - 30);
    }

    @Test
    void sudoku() {
        assertThat(Scoring.score(GameType.SUDOKU, solved(2, 0), 1, 300, 0)).isEqualTo(1500 - 200 - 100 - 100);
    }

    @Test
    void ladder() {
        assertThat(Scoring.score(GameType.LADDER, solved(0, 6), 0, 8, 4)).isEqualTo(1000 - 200 - 2);
    }

    @Test
    void floorIs100ForSolved() {
        assertThat(Scoring.score(GameType.QUEENS, solved(0, 0), 50, 99_999, 0)).isEqualTo(100);
    }

    @Test
    void failedAndInvalidScoreZeroExceptMerge() {
        assertThat(Scoring.score(GameType.CONNECT, new Evaluation(Result.FAILED, 4, 0, 0), 0, 1, 0)).isZero();
        assertThat(Scoring.score(GameType.MERGE, Evaluation.invalid(), 0, 1, 0)).isZero();
        assertThat(Scoring.score(GameType.MERGE, new Evaluation(Result.FAILED, 0, 0, 640), 0, 1, 0)).isEqualTo(640);
        assertThat(Scoring.score(GameType.MERGE, new Evaluation(Result.SOLVED, 0, 0, 640), 0, 1, 0)).isEqualTo(1140);
    }
}
