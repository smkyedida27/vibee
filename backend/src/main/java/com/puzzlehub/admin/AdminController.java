package com.puzzlehub.admin;

import com.puzzlehub.catalog.GameType;
import com.puzzlehub.common.ApiException;
import com.puzzlehub.daily.DailyChallengeService;
import com.puzzlehub.daily.Puzzle;
import com.puzzlehub.daily.PuzzleRepository;
import com.puzzlehub.identity.AuthUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Content operations (runbook: disable/replace broken content with an audit trail). ROLE_ADMIN only. */
@RestController
@RequestMapping("/api/v1/admin")
public class AdminController {

    public record Reason(@NotBlank @Size(max = 500) String reason) {}

    private final PuzzleRepository puzzles;
    private final DailyChallengeService daily;
    private final AuditLog audit;

    public AdminController(PuzzleRepository puzzles, DailyChallengeService daily, AuditLog audit) {
        this.puzzles = puzzles;
        this.daily = daily;
        this.audit = audit;
    }

    @GetMapping("/puzzles")
    public List<Puzzle> list(@RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return puzzles.dailyPuzzles(date);
    }

    @PostMapping("/puzzles/{id}/disable")
    @Transactional
    public Map<String, Object> disable(AuthUser admin, @PathVariable UUID id, @Valid @RequestBody Reason body) {
        if (puzzles.setStatus(id, "DISABLED") == 0) throw ApiException.notFound("Puzzle");
        audit.record(admin.id(), "PUZZLE_DISABLE", id.toString(), Map.of("reason", body.reason()));
        return Map.of("puzzleId", id, "status", "DISABLED");
    }

    @PostMapping("/daily/{date}/{gameType}/replace")
    @Transactional
    public Puzzle replace(AuthUser admin, @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                          @PathVariable GameType gameType, @Valid @RequestBody Reason body) {
        Puzzle next = daily.replace(date, gameType);
        audit.record(admin.id(), "DAILY_REPLACE", date + "/" + gameType,
                Map.of("reason", body.reason(), "newPuzzleId", next.id().toString(), "contentVersion", next.contentVersion()));
        return next;
    }

    @PostMapping("/daily/{date}/regenerate")
    @Transactional
    public List<Puzzle> regenerate(AuthUser admin, @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        daily.ensure(date);
        audit.record(admin.id(), "DAILY_ENSURE", date.toString(), Map.of());
        return puzzles.dailyPuzzles(date);
    }
}
