package com.puzzlehub.identity;

import java.time.Instant;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

public record User(UUID id, String firebaseUid, String displayName, int avatarId, String country, String locale,
                   String timezone, LocalTime reminderTime, boolean notificationsEnabled, String friendCode,
                   List<String> roles, Instant createdAt) {}
