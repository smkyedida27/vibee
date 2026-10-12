package com.puzzlehub.daily;

import com.fasterxml.jackson.databind.JsonNode;
import com.puzzlehub.catalog.Difficulty;
import com.puzzlehub.catalog.GameType;

import java.util.UUID;

public record Puzzle(UUID id, GameType gameType, Difficulty difficulty, int rulesVersion, int contentVersion,
                     String checksum, String status, JsonNode content) {}
