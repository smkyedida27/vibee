# Puzzle Hub API

Spring Boot 3.5 / Java 21 modular monolith backing the Puzzle Hub app. The client/server contract
(RNG, puzzle formats, scoring, endpoints) is in [`../docs/CONTRACT.md`](../docs/CONTRACT.md).

## Run locally

```bash
docker run -d --name ph-pg -p 5432:5432 -e POSTGRES_DB=puzzlehub -e POSTGRES_USER=puzzlehub -e POSTGRES_PASSWORD=puzzlehub postgres:16-alpine
../scripts/sync-content.sh                 # copies shared content into src/main/resources/content
SPRING_PROFILES_ACTIVE=dev ./mvnw spring-boot:run
# DB_PORT / PORT override the defaults (5432 / 8080) if those ports are taken.
```

* OpenAPI: `http://localhost:8080/v3/api-docs`, Swagger UI: `/swagger-ui.html`
* Health: `/actuator/health/liveness`, `/actuator/health/readiness`; metrics: `/actuator/prometheus`
* Dev uses fake verifiers: Firebase ID token `fake:<uid>`, Play purchase tokens `test-valid-…`.
  Both are refused at startup under the `prod` profile.

## Test

```bash
./mvnw verify      # unit tests (surefire) + Testcontainers integration tests (*IT, failsafe; needs Docker)
```

## Configuration

| Env var | Purpose |
|---|---|
| `SPRING_PROFILES_ACTIVE` | `dev`, `test` or `prod` (image default `prod`) |
| `SPRING_DATASOURCE_URL` / `_USERNAME` / `_PASSWORD` | PostgreSQL (prod) |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | PostgreSQL (dev profile) |
| `APP_JWT_SECRET` | HS256 signing secret (≥ 32 bytes) |
| `JWT_PRIVATE_KEY` / `JWT_PUBLIC_KEY` | Optional RS256 key pair (base64 PKCS#8 / X.509); takes precedence over the HMAC secret |
| `APP_FIREBASE_PROJECT_ID` | Firebase project whose ID tokens are accepted |
| `APP_PLAY_PACKAGE_NAME` | Android package (default `com.puzzlehub.app`) |
| `APP_PLAY_SERVICE_ACCOUNT_JSON` | Service-account JSON **content** with Android Publisher access (or `PLAY_SERVICE_ACCOUNT_JSON_PATH`) |
| `APP_ENVIRONMENT` | Reported in `/actuator/info` |
| `CORS_ALLOWED_ORIGINS` | Comma-separated origins (web/admin only; the mobile app does not need CORS) |
| `DB_POOL_SIZE`, `PORT`, `OPENAPI_ENABLED` | Tuning |

Logs are JSON (logstash encoder) outside dev/test and carry `requestId` (`X-Request-Id`).
The scheduled daily check logs `DAILY_CHALLENGE_MISSING` if today's set is incomplete — alarm on it.

## Module map (`com.puzzlehub`)

| Package | Responsibility |
|---|---|
| `identity` | Guest accounts, JWT issuing, refresh-token rotation with reuse detection, Firebase linking |
| `catalog` | Game types, difficulty curve (`Difficulty.forDate`), `GET /games` |
| `content` | Shared word list and curated Word Connect puzzles |
| `daily` | Deterministic generators (`daily.gen`), daily scheduler (today + 2 days, Postgres advisory lock), `GET /daily-challenge` |
| `attempts` | Idempotent attempts, server-side validation/replay, scoring, server-measured duration |
| `progress` | Versioned progress snapshot (409 on stale write), streaks, per-game stats |
| `leaderboard` | Daily (per game / overall) and weekly boards, GLOBAL/COUNTRY/FRIENDS, window-function ranking |
| `social` | Profile & preferences, friend codes, account deletion |
| `economy` | Gem/coin wallet with idempotent ledger, gem spends, 7-day login calendar |
| `store` | Product catalog, Google Play purchase verification, entitlements (remove ads, VIP) |
| `notifications` | FCM token registration |
| `admin` | Disable/replace daily puzzles with an audit log (`ROLE_ADMIN`) |
| `common`, `config` | Problem details, request id, body limits, security, rate limiting, CORS |

### Notes

* Only the first non-invalid submission per user and puzzle counts. Leaderboards record SOLVED runs,
  plus MERGE runs that ended without reaching the target (their merge score still ranks).
* A replaced daily puzzle returns `410 PUZZLE_DISABLED` for new attempts; entries already ranked stay.
* Rate limiting is per instance (bucket4j). Implement `config.RateLimiter` over Redis when scaling out.
* Admin role: `update users set roles = 'USER,ADMIN' where id = …`, then refresh the session.
