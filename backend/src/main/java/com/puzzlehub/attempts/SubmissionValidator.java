package com.puzzlehub.attempts;

import com.fasterxml.jackson.databind.JsonNode;
import com.puzzlehub.content.ContentRepository;
import com.puzzlehub.daily.Puzzle;
import com.puzzlehub.daily.gen.Ladder;
import com.puzzlehub.daily.gen.MergeEngine;
import com.puzzlehub.daily.gen.Queens;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** Replays/validates submissions per game rules. Never trusts client-reported outcomes. */
@Component
public class SubmissionValidator {

    static final int MAX_MERGE_MOVES = 5000;
    private final ContentRepository dictionary;

    public SubmissionValidator(ContentRepository content) {
        this.dictionary = content;
    }

    public Evaluation evaluate(Puzzle puzzle, JsonNode submission) {
        if (submission == null || !submission.isObject()) return Evaluation.invalid();
        try {
            return switch (puzzle.gameType()) {
                case CONNECT -> connect(puzzle.content(), submission.get("guesses"));
                case QUEENS -> queens(puzzle.content(), submission.get("queens"));
                case SUDOKU -> sudoku(puzzle.content(), submission);
                case LADDER -> ladder(puzzle.content(), submission.get("path"));
                case MERGE -> merge(puzzle.content(), submission.get("moves"));
            };
        } catch (RuntimeException e) {
            return Evaluation.invalid();
        }
    }

    static Evaluation connect(JsonNode content, JsonNode guesses) {
        if (guesses == null || !guesses.isArray() || guesses.size() > 64) return Evaluation.invalid();
        Set<String> all = new HashSet<>();
        content.get("words").forEach(w -> all.add(w.asText()));
        List<Set<String>> groups = new ArrayList<>();
        content.get("groups").forEach(g -> {
            Set<String> s = new HashSet<>();
            g.get("words").forEach(w -> s.add(w.asText()));
            groups.add(s);
        });
        Set<Set<String>> solved = new HashSet<>();
        Set<Set<String>> wrong = new HashSet<>();
        int mistakes = 0;
        for (JsonNode guess : guesses) {
            if (solved.size() == groups.size() || mistakes >= 4) break;
            if (!guess.isArray() || guess.size() != 4) return Evaluation.invalid();
            Set<String> g = new HashSet<>();
            guess.forEach(w -> g.add(w.asText()));
            if (g.size() != 4 || !all.containsAll(g)) return Evaluation.invalid();
            if (groups.contains(g)) {
                solved.add(g);
            } else if (wrong.add(g)) {
                mistakes++;
            }
        }
        boolean done = solved.size() == groups.size();
        return new Evaluation(done ? Result.SOLVED : Result.FAILED, mistakes, guesses.size(), 0);
    }

    static Evaluation queens(JsonNode content, JsonNode queens) {
        if (queens == null || !queens.isArray()) return Evaluation.invalid();
        List<List<Integer>> regions = new ArrayList<>();
        content.get("regions").forEach(row -> {
            List<Integer> r = new ArrayList<>();
            row.forEach(v -> r.add(v.asInt()));
            regions.add(r);
        });
        List<Integer> q = new ArrayList<>();
        for (JsonNode v : queens) {
            if (!v.isInt()) return Evaluation.invalid();
            q.add(v.asInt());
        }
        return Queens.isValid(regions, q) ? new Evaluation(Result.SOLVED, 0, 0, 0) : Evaluation.invalid();
    }

    static Evaluation sudoku(JsonNode content, JsonNode submission) {
        JsonNode gridNode = submission.get("grid");
        if (gridNode == null || !gridNode.isTextual()) return Evaluation.invalid();
        String grid = gridNode.asText();
        String givens = content.get("givens").asText();
        if (grid.length() != 81 || !grid.matches("[1-9]{81}")) return Evaluation.invalid();
        for (int i = 0; i < 81; i++) {
            if (givens.charAt(i) != '0' && givens.charAt(i) != grid.charAt(i)) return Evaluation.invalid();
        }
        for (int u = 0; u < 9; u++) {
            int row = 0, col = 0, box = 0;
            for (int k = 0; k < 9; k++) {
                row |= 1 << (grid.charAt(u * 9 + k) - '0');
                col |= 1 << (grid.charAt(k * 9 + u) - '0');
                box |= 1 << (grid.charAt((u / 3 * 3 + k / 3) * 9 + u % 3 * 3 + k % 3) - '0');
            }
            if (row != 0x3FE || col != 0x3FE || box != 0x3FE) return Evaluation.invalid();
        }
        int mistakes = submission.path("mistakes").asInt(0);
        if (mistakes < 0) return Evaluation.invalid();
        return new Evaluation(mistakes >= 3 ? Result.FAILED : Result.SOLVED, mistakes, 0, 0);
    }

    Evaluation ladder(JsonNode content, JsonNode path) {
        if (path == null || !path.isArray() || path.size() < 2 || path.size() > 64) return Evaluation.invalid();
        List<String> words = new ArrayList<>();
        path.forEach(w -> words.add(w.asText().toUpperCase()));
        if (!words.getFirst().equals(content.get("start").asText()) || !words.getLast().equals(content.get("target").asText())) {
            return Evaluation.invalid();
        }
        for (int i = 0; i < words.size(); i++) {
            if (!dictionary.isWord4(words.get(i))) return Evaluation.invalid();
            if (i > 0 && !Ladder.oneLetterApart(words.get(i - 1), words.get(i))) return Evaluation.invalid();
        }
        return new Evaluation(Result.SOLVED, 0, words.size() - 1, 0);
    }

    static Evaluation merge(JsonNode content, JsonNode moves) {
        if (moves == null || !moves.isTextual()) return Evaluation.invalid();
        String m = moves.asText();
        if (m.length() > MAX_MERGE_MOVES || !m.matches("[LRUD]*")) return Evaluation.invalid();
        MergeEngine.Outcome o = MergeEngine.replay(content.get("size").asInt(), content.get("seed").asLong(),
                content.get("target").asInt(), m);
        return new Evaluation(o.reachedTarget() ? Result.SOLVED : Result.FAILED, 0, o.effectiveMoves(), o.score());
    }
}
