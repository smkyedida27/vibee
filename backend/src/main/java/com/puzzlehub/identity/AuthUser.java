package com.puzzlehub.identity;

import java.util.UUID;

/** The authenticated caller, resolved from the access token and verified to still exist. */
public record AuthUser(UUID id) {}
