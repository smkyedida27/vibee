package com.puzzlehub.daily.gen;

import com.puzzlehub.catalog.Difficulty;
import com.puzzlehub.common.rng.Mulberry32;

import java.util.LinkedHashMap;
import java.util.Map;

/** Sudoku generation (unique solution) and solution counting with bitmasks. */
public final class Sudoku {

    private Sudoku() {}

    static int targetGivens(Difficulty d) {
        return switch (d) {
            case EASY -> 38;
            case MEDIUM -> 32;
            case HARD -> 28;
            case EXPERT -> 25;
        };
    }

    public static Map<String, Object> generate(Difficulty difficulty, long seed) {
        Mulberry32 rng = new Mulberry32(seed);
        int[] solution = new int[81];
        fill(solution, 0, rng);
        int[] puzzle = solution.clone();
        int[] order = new int[81];
        for (int i = 0; i < 81; i++) order[i] = i;
        rng.shuffle(order);
        int givens = 81;
        int target = targetGivens(difficulty);
        for (int cell : order) {
            if (givens <= target) break;
            int keep = puzzle[cell];
            puzzle[cell] = 0;
            if (countSolutions(puzzle, 2) != 1) {
                puzzle[cell] = keep;
            } else {
                givens--;
            }
        }
        Map<String, Object> content = new LinkedHashMap<>();
        content.put("givens", toText(puzzle));
        content.put("solution", toText(solution));
        return content;
    }

    private static boolean fill(int[] g, int pos, Mulberry32 rng) {
        if (pos == 81) return true;
        int[] digits = {1, 2, 3, 4, 5, 6, 7, 8, 9};
        rng.shuffle(digits);
        for (int d : digits) {
            if (canPlace(g, pos, d)) {
                g[pos] = d;
                if (fill(g, pos + 1, rng)) return true;
                g[pos] = 0;
            }
        }
        return false;
    }

    private static boolean canPlace(int[] g, int pos, int d) {
        int r = pos / 9, c = pos % 9, br = r / 3 * 3, bc = c / 3 * 3;
        for (int i = 0; i < 9; i++) {
            if (g[r * 9 + i] == d || g[i * 9 + c] == d || g[(br + i / 3) * 9 + bc + i % 3] == d) return false;
        }
        return true;
    }

    /** Counts solutions up to {@code limit}. */
    public static int countSolutions(int[] grid, int limit) {
        int[] rows = new int[9], cols = new int[9], boxes = new int[9];
        for (int i = 0; i < 81; i++) {
            int v = grid[i];
            if (v == 0) continue;
            int bit = 1 << v, r = i / 9, c = i % 9, b = r / 3 * 3 + c / 3;
            if ((rows[r] & bit) != 0 || (cols[c] & bit) != 0 || (boxes[b] & bit) != 0) return 0;
            rows[r] |= bit;
            cols[c] |= bit;
            boxes[b] |= bit;
        }
        return search(grid.clone(), rows, cols, boxes, limit);
    }

    private static int search(int[] g, int[] rows, int[] cols, int[] boxes, int limit) {
        int best = -1, bestMask = 0, bestCount = 10;
        for (int i = 0; i < 81; i++) {
            if (g[i] != 0) continue;
            int r = i / 9, c = i % 9, b = r / 3 * 3 + c / 3;
            int mask = ~(rows[r] | cols[c] | boxes[b]) & 0x3FE;
            int n = Integer.bitCount(mask);
            if (n == 0) return 0;
            if (n < bestCount) {
                best = i;
                bestMask = mask;
                bestCount = n;
                if (n == 1) break;
            }
        }
        if (best < 0) return 1;
        int r = best / 9, c = best % 9, b = r / 3 * 3 + c / 3, found = 0;
        for (int v = 1; v <= 9 && found < limit; v++) {
            int bit = 1 << v;
            if ((bestMask & bit) == 0) continue;
            g[best] = v;
            rows[r] |= bit;
            cols[c] |= bit;
            boxes[b] |= bit;
            found += search(g, rows, cols, boxes, limit - found);
            rows[r] &= ~bit;
            cols[c] &= ~bit;
            boxes[b] &= ~bit;
            g[best] = 0;
        }
        return found;
    }

    public static String toText(int[] g) {
        StringBuilder sb = new StringBuilder(81);
        for (int v : g) sb.append((char) ('0' + v));
        return sb.toString();
    }

    public static int[] fromText(String s) {
        int[] g = new int[81];
        for (int i = 0; i < 81; i++) g[i] = s.charAt(i) - '0';
        return g;
    }
}
