package com.puzzlehub.daily.gen;

import com.puzzlehub.catalog.Difficulty;
import com.puzzlehub.catalog.GameType;
import com.puzzlehub.common.rng.Mulberry32;
import com.puzzlehub.content.ContentRepository;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class PuzzleGenerator {

    private final ContentRepository content;

    public PuzzleGenerator(ContentRepository content) {
        this.content = content;
    }

    public static int mergeTarget(Difficulty d) {
        return switch (d) {
            case EASY -> 512;
            case MEDIUM -> 1024;
            case HARD, EXPERT -> 2048;
        };
    }

    public Map<String, Object> generate(GameType type, Difficulty difficulty, long seed) {
        return switch (type) {
            case SUDOKU -> Sudoku.generate(difficulty, seed);
            case QUEENS -> Queens.generate(difficulty, seed);
            case LADDER -> Ladder.generate(difficulty, seed, content.words4(), new HashSet<>(content.words4()));
            case MERGE -> {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("size", 4);
                m.put("seed", new Mulberry32(seed).next());
                m.put("target", mergeTarget(difficulty));
                yield m;
            }
            case CONNECT -> connect(seed);
        };
    }

    private Map<String, Object> connect(long seed) {
        List<ContentRepository.ConnectPuzzle> all = content.connectPuzzles();
        // Daily seeds advance by 7 per day, which is coprime with the corpus size, so puzzles cycle without repeats.
        ContentRepository.ConnectPuzzle p = all.get((int) Math.floorMod(seed, (long) all.size()));
        Mulberry32 rng = new Mulberry32(seed);
        List<String> words = new ArrayList<>(p.words());
        rng.shuffle(words);
        List<Map<String, Object>> groups = new ArrayList<>();
        for (ContentRepository.ConnectGroup g : p.groups()) {
            Map<String, Object> gm = new LinkedHashMap<>();
            gm.put("title", g.title());
            gm.put("level", g.level());
            gm.put("words", g.words());
            groups.add(gm);
        }
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("sourceId", p.id());
        m.put("words", words);
        m.put("groups", groups);
        return m;
    }
}
