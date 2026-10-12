package com.puzzlehub.catalog;

import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;
import java.util.Arrays;
import java.util.List;

@RestController
@RequestMapping("/api/v1/games")
public class GamesController {

    public record GameInfo(GameType gameType, String title, String description, int rulesVersion, boolean enabled) {}

    @GetMapping
    public ResponseEntity<List<GameInfo>> games() {
        List<GameInfo> games = Arrays.stream(GameType.values())
                .map(g -> new GameInfo(g, g.title(), g.description(), GameType.RULES_VERSION, true))
                .toList();
        return ResponseEntity.ok().cacheControl(CacheControl.maxAge(Duration.ofMinutes(10)).cachePublic()).body(games);
    }
}
