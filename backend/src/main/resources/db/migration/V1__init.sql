-- Puzzle Hub initial schema. All timestamps are timestamptz (UTC); dates are UTC calendar dates.

create table users (
    id                    uuid primary key,
    firebase_uid          text unique,
    device_id             text,
    display_name          text        not null,
    avatar_id             int         not null default 0 check (avatar_id between 0 and 63),
    country               char(2),
    locale                text        not null default 'en',
    timezone              text        not null default 'UTC',
    reminder_time         time,
    notifications_enabled boolean     not null default false,
    friend_code           text        not null unique,
    roles                 text        not null default 'USER',
    created_at            timestamptz not null default now()
);
create index idx_users_country on users (country);

create table refresh_tokens (
    id          uuid primary key,
    user_id     uuid        not null references users (id) on delete cascade,
    token_hash  text        not null unique,
    expires_at  timestamptz not null,
    revoked_at  timestamptz,
    created_at  timestamptz not null default now()
);
create index idx_refresh_tokens_user on refresh_tokens (user_id);

create table puzzles (
    id              uuid primary key,
    game_type       text        not null check (game_type in ('CONNECT', 'QUEENS', 'SUDOKU', 'LADDER', 'MERGE')),
    difficulty      text        not null check (difficulty in ('EASY', 'MEDIUM', 'HARD', 'EXPERT')),
    rules_version   int         not null,
    content_version int         not null,
    content         jsonb       not null,
    checksum        text        not null,
    status          text        not null default 'ACTIVE' check (status in ('ACTIVE', 'DISABLED')),
    created_at      timestamptz not null default now()
);

create table daily_challenges (
    challenge_date  date not null,
    game_type       text not null,
    puzzle_id       uuid not null references puzzles (id),
    timezone_policy text not null default 'UTC',
    rules_version   int  not null,
    primary key (challenge_date, game_type)
);
create unique index ux_daily_challenges_puzzle on daily_challenges (puzzle_id);

create table attempts (
    id              uuid primary key,
    user_id         uuid        not null references users (id) on delete cascade,
    puzzle_id       uuid        not null references puzzles (id),
    idempotency_key text        not null,
    started_at      timestamptz not null,
    submitted_at    timestamptz,
    result          text check (result in ('SOLVED', 'FAILED', 'INVALID')),
    score           int,
    duration_ms     bigint,
    hints_used      int,
    submission      jsonb,
    counted         boolean     not null default false,
    unique (user_id, idempotency_key)
);
create index idx_attempts_user_puzzle on attempts (user_id, puzzle_id);
-- At most one counted attempt per user and puzzle.
create unique index ux_attempts_counted on attempts (user_id, puzzle_id) where counted;

create table leaderboard_entries (
    challenge_date date        not null,
    game_type      text        not null,
    user_id        uuid        not null references users (id) on delete cascade,
    attempt_id     uuid        not null references attempts (id) on delete cascade,
    score          int         not null,
    duration_ms    bigint      not null,
    submitted_at   timestamptz not null,
    primary key (challenge_date, game_type, user_id)
);
create index idx_lb_rank on leaderboard_entries (challenge_date, game_type, score desc, duration_ms, submitted_at);
create index idx_lb_user on leaderboard_entries (user_id, challenge_date);

create table user_progress (
    user_id    uuid primary key references users (id) on delete cascade,
    version    bigint      not null,
    data       jsonb       not null,
    updated_at timestamptz not null
);

create table streaks (
    user_id              uuid primary key references users (id) on delete cascade,
    current_streak       int  not null default 0 check (current_streak >= 0),
    best_streak          int  not null default 0 check (best_streak >= 0),
    last_qualifying_date date
);

create table friendships (
    user_id    uuid        not null references users (id) on delete cascade,
    friend_id  uuid        not null references users (id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (user_id, friend_id),
    check (user_id <> friend_id)
);

create table wallets (
    user_id uuid primary key references users (id) on delete cascade,
    coins   bigint not null default 0 check (coins >= 0),
    gems    bigint not null default 0 check (gems >= 0)
);

create table wallet_ledger (
    id              bigserial primary key,
    user_id         uuid        not null references users (id) on delete cascade,
    currency        text        not null check (currency in ('COINS', 'GEMS')),
    delta           bigint      not null,
    reason          text        not null,
    idempotency_key text        not null,
    created_at      timestamptz not null default now(),
    unique (user_id, idempotency_key, currency)
);

create table daily_rewards (
    user_id         uuid primary key references users (id) on delete cascade,
    last_claim_date date not null,
    cycle_day       int  not null check (cycle_day between 1 and 7)
);

create table purchases (
    id             uuid primary key,
    user_id        uuid references users (id) on delete set null,
    product_id     text        not null,
    purchase_token text        not null unique,
    order_id       text,
    created_at     timestamptz not null default now()
);

create table entitlements (
    user_id    uuid primary key references users (id) on delete cascade,
    remove_ads boolean not null default false,
    vip_until  timestamptz
);

create table push_tokens (
    token      text primary key,
    user_id    uuid        not null references users (id) on delete cascade,
    platform   text        not null,
    updated_at timestamptz not null default now()
);
create index idx_push_tokens_user on push_tokens (user_id);

create table audit_log (
    id         bigserial primary key,
    actor_id   uuid,
    action     text        not null,
    target     text        not null,
    details    jsonb,
    created_at timestamptz not null default now()
);
