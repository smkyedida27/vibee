package com.puzzlehub.daily.gen;

import com.puzzlehub.catalog.Difficulty;
import com.puzzlehub.common.rng.Mulberry32;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Word ladder generation by BFS over the shared dictionary. */
public final class Ladder {

    private Ladder() {}

    public static int distanceFor(Difficulty d) {
        return switch (d) {
            case EASY -> 3;
            case MEDIUM -> 4;
            case HARD -> 5;
            case EXPERT -> 6;
        };
    }

    public static Map<String, Object> generate(Difficulty difficulty, long seed, List<String> dictionary, Set<String> words) {
        Mulberry32 rng = new Mulberry32(seed);
        int distance = distanceFor(difficulty);
        for (int attempt = 0; attempt < 200; attempt++) {
            String start = dictionary.get(rng.nextInt(dictionary.size()));
            Map<String, Integer> dist = bfs(start, words);
            List<String> candidates = new ArrayList<>();
            for (String w : dictionary) if (dist.getOrDefault(w, -1) == distance) candidates.add(w);
            if (candidates.isEmpty()) continue;
            String target = candidates.get(rng.nextInt(candidates.size()));
            Map<String, Object> content = new LinkedHashMap<>();
            content.put("start", start);
            content.put("target", target);
            content.put("par", distance);
            return content;
        }
        throw new IllegalStateException("Unable to generate a ladder for seed " + seed);
    }

    public static Map<String, Integer> bfs(String start, Set<String> words) {
        Map<String, Integer> dist = new HashMap<>();
        ArrayDeque<String> q = new ArrayDeque<>();
        dist.put(start, 0);
        q.add(start);
        while (!q.isEmpty()) {
            String w = q.poll();
            int d = dist.get(w);
            for (String next : neighbors(w, words)) {
                if (dist.putIfAbsent(next, d + 1) == null) q.add(next);
            }
        }
        return dist;
    }

    static List<String> neighbors(String w, Set<String> words) {
        List<String> out = new ArrayList<>();
        char[] chars = w.toCharArray();
        for (int i = 0; i < chars.length; i++) {
            char orig = chars[i];
            for (char ch = 'A'; ch <= 'Z'; ch++) {
                if (ch == orig) continue;
                chars[i] = ch;
                String candidate = new String(chars);
                if (words.contains(candidate)) out.add(candidate);
            }
            chars[i] = orig;
        }
        return out;
    }

    public static boolean oneLetterApart(String a, String b) {
        if (a.length() != b.length()) return false;
        int diff = 0;
        for (int i = 0; i < a.length(); i++) if (a.charAt(i) != b.charAt(i)) diff++;
        return diff == 1;
    }
}
