package com.puzzlehub.attempts;

/** Outcome of validating a submission. {@code mistakes}/{@code steps}/{@code mergeScore} feed scoring. */
public record Evaluation(Result result, int mistakes, int steps, int mergeScore) {

    public static Evaluation invalid() {
        return new Evaluation(Result.INVALID, 0, 0, 0);
    }
}
