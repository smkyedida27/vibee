package com.puzzlehub.daily;

import com.fasterxml.jackson.databind.JsonNode;
import com.puzzlehub.catalog.Difficulty;
import com.puzzlehub.catalog.GameType;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/daily-challenge")
public class DailyController {

    public record DailyPuzzleDto(UUID puzzleId, GameType gameType, Difficulty difficulty, int rulesVersion,
                                 int contentVersion, String checksum, JsonNode content) {}

    public record DailyChallengeDto(LocalDate date, Instant nextResetAt, List<DailyPuzzleDto> puzzles) {}

    private final DailyChallengeService service;

    public DailyController(DailyChallengeService service) {
        this.service = service;
    }

    @GetMapping
    public ResponseEntity<DailyChallengeDto> get(@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        LocalDate d = date == null ? service.today() : date;
        List<DailyPuzzleDto> puzzles = service.challenge(d).stream()
                .map(p -> new DailyPuzzleDto(p.id(), p.gameType(), p.difficulty(), p.rulesVersion(), p.contentVersion(),
                        p.checksum(), p.content()))
                .toList();
        Instant reset = d.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();
        return ResponseEntity.ok().cacheControl(CacheControl.maxAge(Duration.ofMinutes(5)).cachePublic())
                .body(new DailyChallengeDto(d, reset, puzzles));
    }
}
