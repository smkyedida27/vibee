package com.puzzlehub.daily.gen;

import com.puzzlehub.catalog.Difficulty;
import com.puzzlehub.common.rng.Mulberry32;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Queens generation: plant a non-touching permutation, grow one colour region per crown, then
 * hill-climb by reassigning border cells until the puzzle has exactly one solution.
 */
public final class Queens {

    private static final int[][] DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};

    private Queens() {}

    public static int sizeFor(Difficulty d) {
        return switch (d) {
            case EASY -> 7;
            case MEDIUM -> 8;
            case HARD, EXPERT -> 9;
        };
    }

    public static Map<String, Object> generate(Difficulty difficulty, long seed) {
        int n = sizeFor(difficulty);
        Mulberry32 rng = new Mulberry32(seed);
        for (int restart = 0; restart < 500; restart++) {
            int[] queens = new int[n];
            if (!place(queens, 0, n, rng)) continue;
            int[][] regions = grow(queens, n, rng);
            if (climb(regions, queens, n, rng)) {
                // Relabel regions so region ids carry no information about the solution rows.
                int[] perm = new int[n];
                for (int i = 0; i < n; i++) perm[i] = i;
                rng.shuffle(perm);
                List<List<Integer>> rows = new ArrayList<>();
                for (int r = 0; r < n; r++) {
                    List<Integer> row = new ArrayList<>();
                    for (int c = 0; c < n; c++) row.add(perm[regions[r][c]]);
                    rows.add(row);
                }
                List<Integer> solution = new ArrayList<>();
                for (int q : queens) solution.add(q);
                Map<String, Object> content = new LinkedHashMap<>();
                content.put("size", n);
                content.put("regions", rows);
                content.put("solution", solution);
                return content;
            }
        }
        throw new IllegalStateException("Unable to generate a unique Queens puzzle for seed " + seed);
    }

    private static boolean place(int[] q, int row, int n, Mulberry32 rng) {
        if (row == n) return true;
        int[] cols = new int[n];
        for (int i = 0; i < n; i++) cols[i] = i;
        rng.shuffle(cols);
        for (int c : cols) {
            boolean ok = true;
            for (int r = 0; r < row; r++) if (q[r] == c) { ok = false; break; }
            if (ok && row > 0 && Math.abs(q[row - 1] - c) <= 1) ok = false;
            if (!ok) continue;
            q[row] = c;
            if (place(q, row + 1, n, rng)) return true;
        }
        return false;
    }

    private static int[][] grow(int[] queens, int n, Mulberry32 rng) {
        int[][] reg = new int[n][n];
        for (int[] row : reg) java.util.Arrays.fill(row, -1);
        for (int r = 0; r < n; r++) reg[r][queens[r]] = r;
        int unassigned = n * n - n;
        while (unassigned > 0) {
            int k = rng.nextInt(n);
            List<int[]> frontier = new ArrayList<>();
            for (int r = 0; r < n; r++) {
                for (int c = 0; c < n; c++) {
                    if (reg[r][c] != -1) continue;
                    for (int[] d : DIRS) {
                        int rr = r + d[0], cc = c + d[1];
                        if (rr >= 0 && rr < n && cc >= 0 && cc < n && reg[rr][cc] == k) {
                            frontier.add(new int[]{r, c});
                            break;
                        }
                    }
                }
            }
            if (frontier.isEmpty()) continue;
            int[] cell = frontier.get(rng.nextInt(frontier.size()));
            reg[cell[0]][cell[1]] = k;
            unassigned--;
        }
        return reg;
    }

    /**
     * Breaks rival solutions: take a cell of a solution that differs from the planted one and move it into a
     * neighbouring region (keeping its old region contiguous) until the planted solution is the only one.
     */
    private static boolean climb(int[][] reg, int[] queens, int n, Mulberry32 rng) {
        int maxSteps = 3 * n * n;
        for (int step = 0; step < maxSteps; step++) {
            int[] rival = findOther(reg, n, queens);
            if (rival == null) return true;
            List<Integer> rows = new ArrayList<>();
            for (int r = 0; r < n; r++) if (rival[r] != queens[r]) rows.add(r);
            int r = rows.get(rng.nextInt(rows.size()));
            int c = rival[r];
            int from = reg[r][c];
            List<Integer> targets = new ArrayList<>();
            for (int[] d : DIRS) {
                int rr = r + d[0], cc = c + d[1];
                if (rr >= 0 && rr < n && cc >= 0 && cc < n && reg[rr][cc] != from && !targets.contains(reg[rr][cc])) {
                    targets.add(reg[rr][cc]);
                }
            }
            if (targets.isEmpty()) continue;
            reg[r][c] = targets.get(rng.nextInt(targets.size()));
            if (!connected(reg, n, from)) reg[r][c] = from;
        }
        return findOther(reg, n, queens) == null;
    }

    /** Any valid placement other than {@code planted}, or null if the planted one is unique. */
    static int[] findOther(int[][] reg, int n, int[] planted) {
        int[] cur = new int[n];
        return other(reg, n, 0, 0, 0, -10, cur, planted) ? cur : null;
    }

    private static boolean other(int[][] reg, int n, int row, int colMask, int regMask, int prev, int[] cur, int[] planted) {
        if (row == n) return !java.util.Arrays.equals(cur, planted);
        for (int c = 0; c < n; c++) {
            if ((colMask & (1 << c)) != 0 || Math.abs(c - prev) <= 1) continue;
            int region = reg[row][c];
            if ((regMask & (1 << region)) != 0) continue;
            cur[row] = c;
            if (other(reg, n, row + 1, colMask | (1 << c), regMask | (1 << region), c, cur, planted)) return true;
        }
        return false;
    }

    private static boolean connected(int[][] reg, int n, int region) {
        int total = 0, sr = -1, sc = -1;
        for (int r = 0; r < n; r++) for (int c = 0; c < n; c++) if (reg[r][c] == region) { total++; sr = r; sc = c; }
        if (total == 0) return false;
        boolean[][] seen = new boolean[n][n];
        ArrayDeque<int[]> q = new ArrayDeque<>();
        q.add(new int[]{sr, sc});
        seen[sr][sc] = true;
        int visited = 0;
        while (!q.isEmpty()) {
            int[] p = q.poll();
            visited++;
            for (int[] d : DIRS) {
                int rr = p[0] + d[0], cc = p[1] + d[1];
                if (rr >= 0 && rr < n && cc >= 0 && cc < n && !seen[rr][cc] && reg[rr][cc] == region) {
                    seen[rr][cc] = true;
                    q.add(new int[]{rr, cc});
                }
            }
        }
        return visited == total;
    }

    /** Counts valid placements up to {@code limit}. */
    public static int countSolutions(int[][] reg, int n, int limit) {
        return count(reg, n, 0, 0, 0, -10, limit);
    }

    private static int count(int[][] reg, int n, int row, int colMask, int regMask, int prev, int limit) {
        if (row == n) return 1;
        int found = 0;
        for (int c = 0; c < n && found < limit; c++) {
            if ((colMask & (1 << c)) != 0 || Math.abs(c - prev) <= 1) continue;
            int region = reg[row][c];
            if ((regMask & (1 << region)) != 0) continue;
            found += count(reg, n, row + 1, colMask | (1 << c), regMask | (1 << region), c, limit - found);
        }
        return found;
    }

    /** Validates a submitted placement against the contract rules. */
    public static boolean isValid(List<List<Integer>> regions, List<Integer> queens) {
        int n = regions.size();
        if (queens == null || queens.size() != n) return false;
        boolean[] cols = new boolean[n], regs = new boolean[n];
        for (int r = 0; r < n; r++) {
            Integer c = queens.get(r);
            if (c == null || c < 0 || c >= n || cols[c]) return false;
            cols[c] = true;
            int region = regions.get(r).get(c);
            if (region < 0 || region >= n || regs[region]) return false;
            regs[region] = true;
            if (r > 0 && Math.abs(queens.get(r - 1) - c) <= 1) return false;
        }
        return true;
    }
}
