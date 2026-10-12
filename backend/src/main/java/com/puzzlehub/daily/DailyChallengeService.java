package com.puzzlehub.daily;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.puzzlehub.catalog.Difficulty;
import com.puzzlehub.catalog.GameType;
import com.puzzlehub.common.ApiException;
import com.puzzlehub.common.Hashing;
import com.puzzlehub.daily.gen.PuzzleGenerator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class DailyChallengeService {

    private static final Logger log = LoggerFactory.getLogger(DailyChallengeService.class);

    private final PuzzleRepository puzzles;
    private final PuzzleGenerator generator;
    private final ObjectMapper canonical;
    private final ObjectMapper mapper;
    private final Clock clock;

    public DailyChallengeService(PuzzleRepository puzzles, PuzzleGenerator generator, ObjectMapper mapper, Clock clock) {
        this.puzzles = puzzles;
        this.generator = generator;
        this.mapper = mapper;
        this.canonical = mapper.copy().configure(SerializationFeature.ORDER_MAP_ENTRIES_BY_KEYS, true);
        this.clock = clock;
    }

    public LocalDate today() {
        return LocalDate.now(clock.withZone(ZoneOffset.UTC));
    }

    /** Deterministic seed: advances by 7 per day so CONNECT cycles through its whole corpus. */
    public static long seed(LocalDate date, GameType type, int variant) {
        return date.toEpochDay() * 7 + type.ordinal() + variant * 55_433L;
    }

    /** Ensures all game slots exist for {@code date}; safe across instances via an advisory lock. */
    @Transactional
    public void ensure(LocalDate date) {
        puzzles.lockDate(date);
        List<GameType> existing = puzzles.existingTypes(date);
        for (GameType type : GameType.values()) {
            if (existing.contains(type)) continue;
            Puzzle p = build(date, type, 0);
            puzzles.insert(p);
            puzzles.assignDaily(date, type, p.id());
            log.info("Generated daily {} {} puzzle {}", date, type, p.id());
        }
    }

    Puzzle build(LocalDate date, GameType type, int variant) {
        Difficulty difficulty = Difficulty.forDate(date);
        Map<String, Object> content = generator.generate(type, difficulty, seed(date, type, variant));
        JsonNode node = mapper.valueToTree(content);
        return new Puzzle(UUID.randomUUID(), type, difficulty, GameType.RULES_VERSION, variant + 1,
                checksum(node), "ACTIVE", node);
    }

    String checksum(JsonNode content) {
        try {
            Object plain = canonical.treeToValue(content, Object.class);
            return Hashing.sha256Hex(canonical.writeValueAsString(plain));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    /** Published puzzles for a date. Future dates are never exposed. */
    @Transactional
    public List<Puzzle> challenge(LocalDate date) {
        if (date.isAfter(today())) {
            throw ApiException.badRequest("DATE_IN_FUTURE", "Daily challenges are only available up to today (UTC)");
        }
        if (puzzles.existingTypes(date).size() < GameType.values().length) ensure(date);
        return puzzles.dailyPuzzles(date).stream().filter(p -> "ACTIVE".equals(p.status())).toList();
    }

    /** Replaces a broken daily puzzle with a freshly generated, versioned variant. */
    @Transactional
    public Puzzle replace(LocalDate date, GameType type) {
        puzzles.lockDate(date);
        Puzzle current = puzzles.dailyPuzzle(date, type).orElseThrow(() -> ApiException.notFound("Daily puzzle"));
        Puzzle next = build(date, type, current.contentVersion());
        puzzles.insert(next);
        puzzles.setStatus(current.id(), "DISABLED");
        puzzles.assignDaily(date, type, next.id());
        return next;
    }
}
