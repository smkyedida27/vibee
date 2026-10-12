package com.puzzlehub.daily.gen;

import com.puzzlehub.catalog.Difficulty;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class QueensTest {

    @ParameterizedTest
    @EnumSource(Difficulty.class)
    @SuppressWarnings("unchecked")
    void generatesUniqueContiguousPuzzles(Difficulty d) {
        for (long seed = 1; seed <= 10; seed++) {
            Map<String, Object> c = Queens.generate(d, seed * 31 + d.ordinal());
            int n = (int) c.get("size");
            assertThat(n).isEqualTo(Queens.sizeFor(d));
            List<List<Integer>> regions = (List<List<Integer>>) c.get("regions");
            List<Integer> solution = (List<Integer>) c.get("solution");
            int[][] reg = new int[n][n];
            for (int r = 0; r < n; r++) for (int col = 0; col < n; col++) reg[r][col] = regions.get(r).get(col);
            assertThat(Queens.countSolutions(reg, n, 5)).isEqualTo(1);
            assertThat(Queens.isValid(regions, solution)).isTrue();
            assertThat(regions.stream().flatMap(List::stream).distinct().count()).isEqualTo(n);
        }
    }

    @ParameterizedTest
    @EnumSource(Difficulty.class)
    void isDeterministic(Difficulty d) {
        assertThat(Queens.generate(d, 5)).isEqualTo(Queens.generate(d, 5));
    }

    @org.junit.jupiter.api.Test
    void rejectsTouchingAndDuplicateRegions() {
        List<List<Integer>> regions = List.of(
                List.of(0, 0, 1, 1), List.of(0, 2, 2, 1), List.of(3, 2, 2, 1), List.of(3, 3, 3, 1));
        assertThat(Queens.isValid(regions, List.of(0, 1, 3, 2))).isFalse(); // rows 0/1 touch diagonally
        assertThat(Queens.isValid(regions, List.of(0, 0, 3, 2))).isFalse(); // same column
        assertThat(Queens.isValid(regions, List.of(1, 3))).isFalse(); // wrong length
    }
}
