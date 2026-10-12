package com.puzzlehub.daily.gen;

import com.puzzlehub.common.rng.Mulberry32;

/** Deterministic 4×4 sliding-merge engine; bit-for-bit identical to the app (docs/CONTRACT.md §3 MERGE). */
public final class MergeEngine {

    public record Outcome(boolean reachedTarget, boolean gameOver, int score, int maxTile, int effectiveMoves) {}

    private final int size;
    private final int[] cells;
    private final Mulberry32 rng;
    private int score;

    public MergeEngine(int size, long seed) {
        this.size = size;
        this.cells = new int[size * size];
        this.rng = new Mulberry32(seed);
        spawn();
        spawn();
    }

    public int[] cells() {
        return cells.clone();
    }

    public int score() {
        return score;
    }

    private void spawn() {
        int empties = 0;
        for (int v : cells) if (v == 0) empties++;
        if (empties == 0) return;
        int idx = rng.nextInt(empties);
        int value = rng.nextInt(10) == 0 ? 4 : 2;
        for (int i = 0; i < cells.length; i++) {
            if (cells[i] != 0) continue;
            if (idx-- == 0) {
                cells[i] = value;
                return;
            }
        }
    }

    /** Applies a move (L/R/U/D). Returns false for a no-op (nothing moved, no spawn). */
    public boolean move(char dir) {
        boolean changed = false;
        for (int line = 0; line < size; line++) {
            int[] idx = new int[size];
            for (int k = 0; k < size; k++) {
                idx[k] = switch (dir) {
                    case 'L' -> line * size + k;
                    case 'R' -> line * size + (size - 1 - k);
                    case 'U' -> k * size + line;
                    case 'D' -> (size - 1 - k) * size + line;
                    default -> throw new IllegalArgumentException("Bad move " + dir);
                };
            }
            int[] out = new int[size];
            int w = 0, pending = 0;
            for (int k = 0; k < size; k++) {
                int v = cells[idx[k]];
                if (v == 0) continue;
                if (pending == v) {
                    out[w++] = v * 2;
                    score += v * 2;
                    pending = 0;
                } else {
                    if (pending != 0) out[w++] = pending;
                    pending = v;
                }
            }
            if (pending != 0) out[w] = pending;
            for (int k = 0; k < size; k++) {
                if (cells[idx[k]] != out[k]) {
                    changed = true;
                    cells[idx[k]] = out[k];
                }
            }
        }
        if (changed) spawn();
        return changed;
    }

    public boolean canMove() {
        for (int r = 0; r < size; r++) {
            for (int c = 0; c < size; c++) {
                int v = cells[r * size + c];
                if (v == 0) return true;
                if (c + 1 < size && cells[r * size + c + 1] == v) return true;
                if (r + 1 < size && cells[(r + 1) * size + c] == v) return true;
            }
        }
        return false;
    }

    public int maxTile() {
        int m = 0;
        for (int v : cells) m = Math.max(m, v);
        return m;
    }

    /** Replays a move log; stops at the first terminal state (target reached or no moves left). */
    public static Outcome replay(int size, long seed, int target, String moves) {
        MergeEngine e = new MergeEngine(size, seed);
        int effective = 0;
        for (int i = 0; i < moves.length(); i++) {
            if (e.maxTile() >= target || !e.canMove()) break;
            if (e.move(moves.charAt(i))) effective++;
        }
        return new Outcome(e.maxTile() >= target, !e.canMove(), e.score, e.maxTile(), effective);
    }
}
