package com.puzzlehub.catalog;

public enum GameType {
    CONNECT("Word Connect", "Group 16 words into 4 hidden categories"),
    QUEENS("Queens", "One crown per row, column and colour region"),
    SUDOKU("Sudoku", "Classic 9×9 number placement"),
    LADDER("Word Ladder", "Change one letter at a time to reach the target"),
    MERGE("Number Merge", "Slide and merge tiles to reach the target");

    public static final int RULES_VERSION = 1;

    private final String title;
    private final String description;

    GameType(String title, String description) {
        this.title = title;
        this.description = description;
    }

    public String title() { return title; }

    public String description() { return description; }
}
