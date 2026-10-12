package com.puzzlehub.leaderboard;

import com.puzzlehub.catalog.GameType;
import com.puzzlehub.common.ApiException;
import com.puzzlehub.daily.DailyChallengeService;
import com.puzzlehub.identity.AuthUser;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

@Validated
@RestController
@RequestMapping("/api/v1/leaderboards")
public class LeaderboardController {

    private final LeaderboardService service;
    private final DailyChallengeService daily;

    public LeaderboardController(LeaderboardService service, DailyChallengeService daily) {
        this.service = service;
        this.daily = daily;
    }

    @GetMapping("/daily")
    public LeaderboardService.Page daily(AuthUser user,
                                         @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                         @RequestParam(required = false) GameType gameType,
                                         @RequestParam(defaultValue = "GLOBAL") LeaderboardService.Scope scope,
                                         @RequestParam(defaultValue = "0") @Min(0) @Max(10_000) int page,
                                         @RequestParam(defaultValue = "50") @Min(1) @Max(100) int size) {
        LocalDate d = date == null ? daily.today() : date;
        if (d.isAfter(daily.today())) throw ApiException.badRequest("DATE_IN_FUTURE", "No leaderboard for future dates");
        return service.daily(user.id(), d, gameType, scope, page, size);
    }

    @GetMapping("/weekly")
    public LeaderboardService.Page weekly(AuthUser user,
                                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                          @RequestParam(defaultValue = "GLOBAL") LeaderboardService.Scope scope,
                                          @RequestParam(defaultValue = "0") @Min(0) @Max(10_000) int page,
                                          @RequestParam(defaultValue = "50") @Min(1) @Max(100) int size) {
        return service.weekly(user.id(), date == null ? daily.today() : date, scope, page, size);
    }
}
