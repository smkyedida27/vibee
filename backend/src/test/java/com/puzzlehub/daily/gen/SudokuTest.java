package com.puzzlehub.daily.gen;

import com.puzzlehub.catalog.Difficulty;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class SudokuTest {

    @ParameterizedTest
    @EnumSource(Difficulty.class)
    void generatesUniqueConsistentPuzzles(Difficulty d) {
        for (long seed = 1; seed <= 5; seed++) {
            Map<String, Object> c = Sudoku.generate(d, seed * 7919 + d.ordinal());
            String givens = (String) c.get("givens");
            String solution = (String) c.get("solution");
            int[] g = Sudoku.fromText(givens);
            assertThat(Sudoku.countSolutions(g, 2)).isEqualTo(1);
            assertThat(Sudoku.countSolutions(Sudoku.fromText(solution), 2)).isEqualTo(1);
            assertThat(solution).matches("[1-9]{81}");
            for (int i = 0; i < 81; i++) {
                if (givens.charAt(i) != '0') assertThat(givens.charAt(i)).isEqualTo(solution.charAt(i));
            }
            long count = givens.chars().filter(ch -> ch != '0').count();
            assertThat(count).isLessThanOrEqualTo(Sudoku.targetGivens(d) + 6);
        }
    }

    @ParameterizedTest
    @EnumSource(Difficulty.class)
    void isDeterministic(Difficulty d) {
        assertThat(Sudoku.generate(d, 99)).isEqualTo(Sudoku.generate(d, 99));
    }
}
