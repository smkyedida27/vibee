package com.puzzlehub.attempts;

import com.puzzlehub.catalog.GameType;

/** Server-side scoring formulas (docs/CONTRACT.md §4). */
public final class Scoring {

    private Scoring() {}

    public static int score(GameType type, Evaluation e, int hints, long seconds, int par) {
        if (e.result() == Result.INVALID) return 0;
        if (type == GameType.MERGE) return e.mergeScore() + (e.result() == Result.SOLVED ? 500 : 0);
        if (e.result() != Result.SOLVED) return 0;
        long raw = switch (type) {
            case CONNECT -> 1000 - 150L * e.mistakes() - 100L * hints - seconds / 4;
            case QUEENS -> 1000 - 100L * hints - seconds / 2;
            case SUDOKU -> 1500 - 100L * e.mistakes() - 100L * hints - seconds / 3;
            case LADDER -> 1000 - 100L * (e.steps() - par) - 100L * hints - seconds / 4;
            case MERGE -> throw new IllegalStateException();
        };
        return (int) Math.max(100, raw);
    }
}
