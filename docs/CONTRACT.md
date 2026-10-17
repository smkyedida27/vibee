# Quintile — Client/Server Contract (v1)

This is the single source of truth shared by the Flutter app (`app/`) and the Spring Boot
backend (`backend/`). Any change here must be reflected in both and in tests.

## 1. Conventions

* Base path: `/api/v1`. JSON only, `camelCase` fields, UTC ISO-8601 timestamps.
* Errors: RFC 7807 `application/problem+json` with `type`, `title`, `status`, `detail`, `code`.
* Every request may carry `X-Request-Id`; the server echoes/creates it and logs it.
* Mutating endpoints that create resources accept an `Idempotency-Key` header **or** an
  `idempotencyKey` body field. Replays return the original response.
* Daily reset: **00:00 UTC**. "Today" is always the UTC date.

## 2. Deterministic RNG — `mulberry32`

Both sides MUST implement exactly this (32-bit unsigned output):

```
next(): a = (a + 0x6D2B79F5) | 0
        t = imul(a ^ (a >>> 15), 1 | a)
        t = (t + imul(t ^ (t >>> 7), 61 | t)) ^ t
        return (t ^ (t >>> 14)) >>> 0          // uint32
nextInt(n) = next() % n
```

Test vectors (first 5 outputs):

| seed | outputs |
|---|---|
| 0 | 1144304738, 1416247, 958946056, 627933444, 2007157716 |
| 1 | 2693262067, 11749833, 2265367787, 4213581821, 4159151403 |
| 42 | 2581720956, 1925393290, 3661312704, 2876485805, 750819978 |
| 20261011 | 1488163886, 3496767163, 2460547021, 1222184908, 208299103 |

Shuffle = Fisher–Yates from the end: `for i = n-1 downTo 1: j = nextInt(i+1); swap(i, j)`.

## 3. Game types

`gameType` ∈ `CONNECT`, `QUEENS`, `SUDOKU`, `LADDER`, `MERGE`. `rulesVersion` = 1 for all.
`difficulty` ∈ `EASY`, `MEDIUM`, `HARD`, `EXPERT`.

### CONNECT — group 16 words into 4 hidden categories
```json
content: {"words":["…16, display order…"],
          "groups":[{"title":"Fruits","level":0,"words":["APPLE","PEAR","PLUM","FIG"]}, …4]}
submission: {"guesses":[["A","B","C","D"], …]}   // in the order made
```
Replay: each guess must be 4 distinct words from the puzzle. A guess equal to an unsolved
group solves it; otherwise it's a mistake. Duplicate guesses (same set as an earlier wrong
guess) are ignored. **SOLVED** iff all 4 groups solved before the 4th mistake. Max 4 mistakes.

### QUEENS — one crown per row, column and colour region; crowns never touch (incl. diagonally)
```json
content: {"size":8,"regions":[[0,0,1,…],…size rows],"solution":[colOfRow0,…]}
submission: {"queens":[colOfRow0, colOfRow1, …]}
```
Valid iff length == size, columns all distinct, regions of the cells all distinct, and for
each adjacent row pair `|c[r]-c[r+1]| > 1`. Generated puzzles have exactly one solution.

### SUDOKU — classic 9×9
```json
content: {"givens":"81 chars, '0' = empty","solution":"81 chars"}
submission: {"grid":"81 chars 1-9","mistakes":0}
```
Valid iff all 81 cells 1-9, givens preserved, every row/col/box a permutation of 1-9.
Generated puzzles have exactly one solution. `mistakes` (client-counted wrong entries) affects
score only; >= 3 mistakes means the player failed locally (no submission).

### LADDER — change one letter at a time to reach the target word
```json
content: {"start":"COLD","target":"WARM","par":4}
submission: {"path":["COLD","CORD","CARD","WARD","WARM"]}
```
Valid iff `path[0]==start`, `last==target`, every word is in `content/words4.txt`, and
consecutive words differ by exactly one letter at the same position. `par` = shortest
number of steps (BFS). Words are uppercase in the API.

### MERGE — 4×4 sliding merge (2048-style) with a seeded spawn sequence
```json
content: {"size":4,"seed":123456789,"target":1024}
submission: {"moves":"LURDDL…"}   // L,R,U,D
```
Engine (both sides identical):
* Board starts empty; spawn twice. **Spawn:** collect empty cells in row-major order,
  `idx = rng.nextInt(empties)`, then `value = rng.nextInt(10) == 0 ? 4 : 2`.
* A move slides all tiles toward the direction; each tile merges at most once per move;
  merging two `v` tiles yields `2v` and adds `2v` to score. Merge priority is from the
  wall in the direction of travel.
* If a move changes nothing it's a no-op (no spawn) and is ignored by the server.
* After every effective move: spawn once.
* **SOLVED** iff a tile >= `target` appears. The run also ends when no move is possible.
  Score = sum of merge values. Server rejects move strings > 5000 chars.

## 4. Scoring (daily, server-computed)

`seconds` = server-measured `submittedAt - attempt.startedAt` (clamped to ≥ client duration).

| game | score |
|---|---|
| CONNECT | `max(100, 1000 - 150*mistakes - 100*hints - floor(seconds/4))` |
| QUEENS | `max(100, 1000 - 100*hints - floor(seconds/2))` |
| SUDOKU | `max(100, 1500 - 100*mistakes - 100*hints - floor(seconds/3))` |
| LADDER | `max(100, 1000 - 100*(steps-par) - 100*hints - floor(seconds/4))` |
| MERGE | merge score (+500 if SOLVED) |

Tie-breakers: score DESC, durationMs ASC, submittedAt ASC. Only the **first** submitted
attempt per user/puzzle counts for leaderboards (replays are practice).

Stars (local levels, 1–3): CONNECT 3★ = 0 mistakes, 2★ ≤ 2. QUEENS 3★ no hints. SUDOKU
3★ = 0 mistakes & no hints, 2★ ≤ 1 mistake. LADDER 3★ steps == par, 2★ ≤ par+2.
MERGE 3★ reach target, 2★ reach target/2, 1★ reach target/4.

## 5. Auth

* `POST /auth/guest {deviceId}` → `{userId, accessToken, refreshToken, expiresIn}`. No sign-up
  needed to play; guests get leaderboards & sync.
* `POST /auth/refresh {refreshToken}` → same shape (refresh token rotates).
* `POST /auth/firebase {idToken}` → links a Firebase account to the current guest (or logs in
  to the existing linked user). Server verifies the token with Firebase public keys.
* Access token: JWT (HS256 in dev, RS256 via env in prod), `sub`=userId, `roles`, 60 min.

## 6. Endpoints

| Method & path | Purpose |
|---|---|
| `GET /games` | game modes, versions, enabled flags |
| `GET /daily-challenge?date=` | `{date, puzzles:[{puzzleId, gameType, difficulty, rulesVersion, contentVersion, checksum, content}]}` (5 puzzles, one per game) |
| `POST /attempts` | `{puzzleId, idempotencyKey}` → `{attemptId, startedAt}` |
| `POST /attempts/{id}/submit` | `{submission, hintsUsed, clientDurationMs}` → `{result: SOLVED\|FAILED\|INVALID, score, durationMs, counted, rank}` |
| `GET /me/progress` / `PUT /me/progress` | opaque snapshot `{version, data}`; PUT with stale `version` → 409 with current copy |
| `GET /me/streak` | `{currentStreak, bestStreak, lastQualifyingDate, todayCompleted:[gameType]}` |
| `GET /me/profile` / `PATCH /me/preferences` | displayName, avatarId, country, locale, timezone, reminderTime, notificationsEnabled, friendCode |
| `GET /me/stats` | per-game played/solved/best/avg |
| `GET/POST /me/friends` | list / add by `friendCode`; `DELETE /me/friends/{userId}` |
| `GET /me/referral` | `{inviteCode, invited, rewarded, maxRewarded, gemsPerInvite, redeemed, canRedeem}` — the invite code is the friend code |
| `POST /me/referral/redeem` | `{code}` → `{inviter, gemsGranted, wallet}`. Once per account, only within 7 days of account creation; both players get 20 wallet gems (inviter rewarded for up to 25 invites) and become friends. Errors: `SELF_INVITE` 400, `ALREADY_REDEEMED`/`INVITE_EXPIRED` 409, 404 unknown code |
| `GET /leaderboards/daily?date&gameType&scope=GLOBAL\|COUNTRY\|FRIENDS&page&size` | `gameType` omitted = overall (sum) |
| `GET /leaderboards/weekly?scope&page&size` | ISO week, overall |
| `GET /me/wallet` | `{coins, gems}` (server-authoritative gems) |
| `POST /me/wallet/spend` | `{sku, idempotencyKey, gems?}`; `gems` (1..price, default the price) lets free gems cover the rest of the price; a key is bound to its sku. Skus: `HEART_REFILL`(30 gems), `HINT_PACK_5`(20), `COINS_1000`(25), `CONTINUE`(up to 24: 12 for the first continue, 24 for the second). The wallet holds **purchased** gems only; free gems (starter, calendar, spin) live in the local snapshot and are spent first |
| `POST /me/rewards/daily-claim` | 7-day login calendar; idempotent per UTC day |
| `GET /store/products` | IAP catalog (product ids, grants) |
| `POST /purchases/google/verify` | `{productId, purchaseToken}` → grants; idempotent per token |
| `GET /me/entitlements` | `{removeAds, vipUntil}` |
| `POST /me/push-token` | FCM token registration |
| `DELETE /me` | account + data deletion |
| `/admin/**` | ROLE_ADMIN: list puzzles, disable/replace a puzzle, regenerate a date (audited) |
| `GET /actuator/health`, `/actuator/prometheus` | ops |

IAP products (Google Play ids): `gems_small` (80), `gems_medium` (500), `gems_large` (1200),
`gems_mega` (3000), `remove_ads` (non-consumable), `vip_monthly` (subscription: no ads,
unlimited hearts, 2× coins, 3 free hints/day).

## 7. Shared content

`content/words4.txt` — LADDER dictionary (uppercase, one per line).
`content/connect.json` — curated CONNECT puzzles. Run `scripts/sync-content.sh` to copy into
`app/assets/content/` and `backend/src/main/resources/content/`; CI fails on drift.
