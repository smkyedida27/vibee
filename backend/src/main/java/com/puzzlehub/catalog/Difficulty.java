package com.puzzlehub.catalog;

import java.time.DayOfWeek;
import java.time.LocalDate;

public enum Difficulty {
    EASY, MEDIUM, HARD, EXPERT;

    /** Published weekly difficulty curve for daily challenges (gentle start of week, hardest Saturday). */
    public static Difficulty forDate(LocalDate date) {
        DayOfWeek d = date.getDayOfWeek();
        return switch (d) {
            case MONDAY -> EASY;
            case TUESDAY, WEDNESDAY, SUNDAY -> MEDIUM;
            case THURSDAY, FRIDAY -> HARD;
            case SATURDAY -> EXPERT;
        };
    }
}
