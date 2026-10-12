package com.puzzlehub.content;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/** Shared, versioned content (see docs/CONTRACT.md §7), loaded once from the classpath. */
@Component
public class ContentRepository {

    public record ConnectGroup(String title, int level, List<String> words) {}

    public record ConnectPuzzle(String id, List<String> words, List<ConnectGroup> groups) {}

    private final Set<String> words4;
    private final List<String> words4Sorted;
    private final List<ConnectPuzzle> connect;

    public ContentRepository(ObjectMapper mapper) throws IOException {
        Set<String> words = new LinkedHashSet<>();
        try (InputStream in = new ClassPathResource("content/words4.txt").getInputStream()) {
            for (String line : new String(in.readAllBytes(), StandardCharsets.UTF_8).split("\n")) {
                String w = line.trim().toUpperCase();
                if (w.matches("[A-Z]{4}")) words.add(w);
            }
        }
        this.words4 = Collections.unmodifiableSet(words);
        List<String> sorted = new ArrayList<>(words);
        Collections.sort(sorted);
        this.words4Sorted = List.copyOf(sorted);

        List<ConnectPuzzle> puzzles = new ArrayList<>();
        try (InputStream in = new ClassPathResource("content/connect.json").getInputStream()) {
            JsonNode root = mapper.readTree(in);
            for (JsonNode p : root.get("puzzles")) {
                List<ConnectGroup> groups = new ArrayList<>();
                for (JsonNode g : p.get("groups")) {
                    groups.add(new ConnectGroup(g.get("title").asText(), g.get("level").asInt(), strings(g.get("words"))));
                }
                puzzles.add(new ConnectPuzzle(p.get("id").asText(), strings(p.get("words")), List.copyOf(groups)));
            }
        }
        if (puzzles.isEmpty() || words4.isEmpty()) throw new IllegalStateException("Content files are empty");
        this.connect = List.copyOf(puzzles);
    }

    private static List<String> strings(JsonNode arr) {
        List<String> out = new ArrayList<>();
        arr.forEach(n -> out.add(n.asText()));
        return List.copyOf(out);
    }

    public boolean isWord4(String w) {
        return w != null && words4.contains(w);
    }

    /** Sorted for deterministic generation. */
    public List<String> words4() {
        return words4Sorted;
    }

    public List<ConnectPuzzle> connectPuzzles() {
        return connect;
    }
}
