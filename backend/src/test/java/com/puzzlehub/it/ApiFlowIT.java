package com.puzzlehub.it;

import com.fasterxml.jackson.databind.JsonNode;
import com.puzzlehub.content.ContentRepository;
import com.puzzlehub.daily.gen.Ladder;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@Testcontainers
@ActiveProfiles("test")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ApiFlowIT {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine");

    @LocalServerPort
    int port;

    @Autowired
    JdbcClient db;

    @Autowired
    ContentRepository content;

    Api api;

    @BeforeEach
    void setUp() {
        api = new Api(port);
    }

    record Session(String userId, String access, String refresh) {}

    Session guest() {
        Api.Res r = api.post("/api/v1/auth/guest", Map.of("deviceId", "device-" + UUID.randomUUID()), null);
        assertThat(r.status()).isEqualTo(200);
        return new Session(r.body().get("userId").asText(), r.body().get("accessToken").asText(),
                r.body().get("refreshToken").asText());
    }

    Map<String, JsonNode> daily() {
        Api.Res r = api.get("/api/v1/daily-challenge", null);
        assertThat(r.status()).isEqualTo(200);
        Map<String, JsonNode> byType = new HashMap<>();
        r.body().get("puzzles").forEach(p -> byType.put(p.get("gameType").asText(), p));
        return byType;
    }

    String attempt(Session s, JsonNode puzzle) {
        Api.Res r = api.post("/api/v1/attempts",
                Map.of("puzzleId", puzzle.get("puzzleId").asText(), "idempotencyKey", "key-" + UUID.randomUUID()), s.access());
        assertThat(r.status()).isEqualTo(201);
        return r.body().get("attemptId").asText();
    }

    Api.Res submit(Session s, String attemptId, Object submission, int hints) {
        return api.post("/api/v1/attempts/" + attemptId + "/submit",
                Map.of("submission", submission, "hintsUsed", hints, "clientDurationMs", 1000), s.access());
    }

    static List<List<String>> connectSolution(JsonNode puzzle) {
        List<List<String>> guesses = new ArrayList<>();
        puzzle.get("content").get("groups").forEach(g -> {
            List<String> words = new ArrayList<>();
            g.get("words").forEach(w -> words.add(w.asText()));
            guesses.add(words);
        });
        return guesses;
    }

    List<String> ladderPath(JsonNode c) {
        String start = c.get("start").asText(), target = c.get("target").asText();
        var words = new HashSet<>(content.words4());
        Map<String, Integer> dist = Ladder.bfs(target, words);
        List<String> path = new ArrayList<>(List.of(start));
        String cur = start;
        while (!cur.equals(target)) {
            for (String w : words) {
                if (Ladder.oneLetterApart(cur, w) && dist.getOrDefault(w, 99) == dist.get(cur) - 1) {
                    cur = w;
                    break;
                }
            }
            path.add(cur);
        }
        return path;
    }

    @Test
    void publicEndpointsAndOps() {
        Api.Res games = api.get("/api/v1/games", null);
        assertThat(games.status()).isEqualTo(200);
        assertThat(games.body()).hasSize(5);
        Map<String, JsonNode> d = daily();
        assertThat(d.keySet()).containsExactlyInAnyOrder("CONNECT", "QUEENS", "SUDOKU", "LADDER", "MERGE");
        d.values().forEach(p -> assertThat(p.get("checksum").asText()).hasSize(64));
        assertThat(api.get("/api/v1/daily-challenge?date=2999-01-01", null).status()).isEqualTo(400);
        assertThat(api.get("/actuator/health", null).status()).isEqualTo(200);
        assertThat(api.get("/actuator/health/readiness", null).status()).isEqualTo(200);
        assertThat(api.get("/v3/api-docs", null).status()).isEqualTo(200);
        Api.Res unauth = api.get("/api/v1/me/streak", null);
        assertThat(unauth.status()).isEqualTo(401);
        assertThat(unauth.body().get("code").asText()).isEqualTo("UNAUTHORIZED");
        assertThat(unauth.header("X-Request-Id")).isEqualTo("it-req-1");
        assertThat(api.get("/api/v1/me/streak", "garbage.token.value").status()).isEqualTo(401);
    }

    @Test
    void fullDailyFlowWithLeaderboardsAndStreaks() {
        Session alice = guest();
        Session bob = guest();
        Map<String, JsonNode> d = daily();

        // Idempotent attempt creation
        String key = "idem-" + UUID.randomUUID();
        Map<String, String> body = Map.of("puzzleId", d.get("CONNECT").get("puzzleId").asText(), "idempotencyKey", key);
        String a1 = api.post("/api/v1/attempts", body, alice.access()).body().get("attemptId").asText();
        String a2 = api.post("/api/v1/attempts", body, alice.access()).body().get("attemptId").asText();
        assertThat(a1).isEqualTo(a2);

        Api.Res solved = submit(alice, a1, Map.of("guesses", connectSolution(d.get("CONNECT"))), 0);
        assertThat(solved.status()).isEqualTo(200);
        assertThat(solved.body().get("result").asText()).isEqualTo("SOLVED");
        assertThat(solved.body().get("counted").asBoolean()).isTrue();
        assertThat(solved.body().get("score").asInt()).isBetween(900, 1000);
        // Re-submitting the same attempt replays the stored result.
        assertThat(submit(alice, a1, Map.of("guesses", List.of()), 0).body().get("score")).isEqualTo(solved.body().get("score"));
        // IDOR: bob cannot submit to alice's attempt.
        Api.Res idor = submit(bob, a1, Map.of("guesses", List.of()), 0);
        assertThat(idor.status()).isEqualTo(404);
        // Only the first attempt counts.
        Api.Res replay = submit(alice, attempt(alice, d.get("CONNECT")), Map.of("guesses", connectSolution(d.get("CONNECT"))), 0);
        assertThat(replay.body().get("counted").asBoolean()).isFalse();

        // Bob: one mistake then solves.
        List<List<String>> bobGuesses = new ArrayList<>();
        List<List<String>> sol = connectSolution(d.get("CONNECT"));
        List<String> wrong = new ArrayList<>(sol.get(0).subList(0, 3));
        wrong.add(sol.get(1).get(0));
        bobGuesses.add(wrong);
        bobGuesses.addAll(sol);
        Api.Res bobRes = submit(bob, attempt(bob, d.get("CONNECT")), Map.of("guesses", bobGuesses), 1);
        assertThat(bobRes.body().get("result").asText()).isEqualTo("SOLVED");
        assertThat(bobRes.body().get("score").asInt()).isLessThan(solved.body().get("score").asInt());

        // Other games for alice.
        JsonNode queens = d.get("QUEENS").get("content");
        assertThat(submit(alice, attempt(alice, d.get("QUEENS")), Map.of("queens", queens.get("solution")), 0)
                .body().get("result").asText()).isEqualTo("SOLVED");
        JsonNode sudoku = d.get("SUDOKU").get("content");
        assertThat(submit(alice, attempt(alice, d.get("SUDOKU")), Map.of("grid", sudoku.get("solution").asText(), "mistakes", 0), 0)
                .body().get("result").asText()).isEqualTo("SOLVED");
        List<String> path = ladderPath(d.get("LADDER").get("content"));
        assertThat(path).hasSize(d.get("LADDER").get("content").get("par").asInt() + 1);
        assertThat(submit(alice, attempt(alice, d.get("LADDER")), Map.of("path", path), 0)
                .body().get("result").asText()).isEqualTo("SOLVED");
        Api.Res merge = submit(alice, attempt(alice, d.get("MERGE")), Map.of("moves", "LURD".repeat(100)), 0);
        assertThat(merge.body().get("result").asText()).isIn("SOLVED", "FAILED");
        assertThat(merge.body().get("counted").asBoolean()).isTrue();
        Api.Res invalid = submit(alice, attempt(alice, d.get("QUEENS")), Map.of("queens", List.of(0, 0)), 0);
        assertThat(invalid.body().get("result").asText()).isEqualTo("INVALID");

        // Streak
        JsonNode streak = api.get("/api/v1/me/streak", alice.access()).body();
        assertThat(streak.get("currentStreak").asInt()).isEqualTo(1);
        assertThat(streak.get("todayCompleted")).hasSize(4);

        // Friends scope isolates the two players from other tests.
        Api.Res friendsOnly = api.get("/api/v1/leaderboards/daily?gameType=CONNECT&scope=FRIENDS", bob.access());
        assertThat(friendsOnly.body().get("total").asInt()).isEqualTo(1);
        String aliceCode = api.get("/api/v1/me/profile", alice.access()).body().get("friendCode").asText();
        assertThat(api.post("/api/v1/me/friends", Map.of("friendCode", aliceCode), bob.access()).status()).isEqualTo(201);
        assertThat(api.get("/api/v1/me/friends", alice.access()).body()).hasSize(1);
        JsonNode lb = api.get("/api/v1/leaderboards/daily?gameType=CONNECT&scope=FRIENDS", bob.access()).body();
        assertThat(lb.get("total").asInt()).isEqualTo(2);
        assertThat(lb.get("entries").get(0).get("userId").asText()).isEqualTo(alice.userId());
        assertThat(lb.get("entries").get(1).get("rank").asInt()).isEqualTo(2);
        assertThat(lb.get("me").get("userId").asText()).isEqualTo(bob.userId());
        JsonNode overall = api.get("/api/v1/leaderboards/daily?scope=FRIENDS", bob.access()).body();
        assertThat(overall.get("entries").get(0).get("score").asLong()).isGreaterThan(solved.body().get("score").asLong());
        assertThat(api.get("/api/v1/leaderboards/weekly?scope=FRIENDS", bob.access()).body().get("total").asInt()).isEqualTo(2);
        assertThat(api.get("/api/v1/leaderboards/daily?size=500", bob.access()).status()).isEqualTo(400);

        // Country scope.
        api.patch("/api/v1/me/preferences", Map.of("country", "IN"), alice.access());
        api.patch("/api/v1/me/preferences", Map.of("country", "IN"), bob.access());
        JsonNode country = api.get("/api/v1/leaderboards/daily?gameType=CONNECT&scope=COUNTRY", bob.access()).body();
        assertThat(country.get("total").asInt()).isGreaterThanOrEqualTo(2);

        // Stats
        JsonNode stats = api.get("/api/v1/me/stats", alice.access()).body();
        assertThat(stats).hasSize(5);
    }

    @Test
    void progressOptimisticConcurrency() {
        Session s = guest();
        assertThat(api.get("/api/v1/me/progress", s.access()).body().get("version").asInt()).isZero();
        Api.Res first = api.put("/api/v1/me/progress", Map.of("version", 0, "data", Map.of("stars", 3)), s.access());
        assertThat(first.status()).isEqualTo(200);
        assertThat(first.body().get("version").asInt()).isEqualTo(1);
        Api.Res stale = api.put("/api/v1/me/progress", Map.of("version", 0, "data", Map.of("stars", 1)), s.access());
        assertThat(stale.status()).isEqualTo(409);
        assertThat(stale.body().get("version").asInt()).isEqualTo(1);
        assertThat(stale.body().get("data").get("stars").asInt()).isEqualTo(3);
        assertThat(api.put("/api/v1/me/progress", Map.of("version", 1, "data", Map.of("stars", 4)), s.access())
                .body().get("version").asInt()).isEqualTo(2);
    }

    @Test
    void economyWalletRewardsAndPurchases() {
        Session s = guest();
        Session other = guest();
        JsonNode claim = api.post("/api/v1/me/rewards/daily-claim", null, s.access()).body();
        assertThat(claim.get("day").asInt()).isEqualTo(1);
        assertThat(claim.get("wallet").get("coins").asInt()).isEqualTo(100);
        assertThat(api.post("/api/v1/me/rewards/daily-claim", null, s.access()).body().get("alreadyClaimed").asBoolean()).isTrue();

        Api.Res broke = api.post("/api/v1/me/wallet/spend", Map.of("sku", "HEART_REFILL", "idempotencyKey", "spend-0001"), s.access());
        assertThat(broke.status()).isEqualTo(409);
        assertThat(broke.body().get("code").asText()).isEqualTo("INSUFFICIENT_FUNDS");

        Map<String, String> buy = Map.of("productId", "gems_small", "purchaseToken", "test-valid-" + UUID.randomUUID());
        assertThat(api.post("/api/v1/purchases/google/verify", buy, s.access()).body().get("wallet").get("gems").asInt()).isEqualTo(80);
        assertThat(api.post("/api/v1/purchases/google/verify", buy, s.access()).body().get("wallet").get("gems").asInt()).isEqualTo(80);
        assertThat(api.post("/api/v1/purchases/google/verify", buy, other.access()).status()).isEqualTo(409);
        assertThat(api.post("/api/v1/purchases/google/verify", Map.of("productId", "gems_small", "purchaseToken", "forged"),
                s.access()).body().get("code").asText()).isEqualTo("PURCHASE_INVALID");

        Map<String, String> spend = Map.of("sku", "HEART_REFILL", "idempotencyKey", "spend-0002");
        assertThat(api.post("/api/v1/me/wallet/spend", spend, s.access()).body().get("wallet").get("gems").asInt()).isEqualTo(50);
        assertThat(api.post("/api/v1/me/wallet/spend", spend, s.access()).body().get("wallet").get("gems").asInt()).isEqualTo(50);
        assertThat(api.get("/api/v1/me/wallet", s.access()).body().get("gems").asInt()).isEqualTo(50);

        Map<String, String> removeAds = Map.of("productId", "remove_ads", "purchaseToken", "test-valid-ra-" + UUID.randomUUID());
        api.post("/api/v1/purchases/google/verify", removeAds, s.access());
        api.post("/api/v1/purchases/google/verify", Map.of("productId", "vip_monthly", "purchaseToken", "test-valid-vip-" + UUID.randomUUID()), s.access());
        JsonNode ent = api.get("/api/v1/me/entitlements", s.access()).body();
        assertThat(ent.get("removeAds").asBoolean()).isTrue();
        assertThat(ent.get("vipActive").asBoolean()).isTrue();

        // Non-consumables follow the Play account to a new guest (e.g. after a reinstall).
        assertThat(api.post("/api/v1/purchases/google/verify", removeAds, other.access()).status()).isEqualTo(200);
        assertThat(api.get("/api/v1/me/entitlements", other.access()).body().get("removeAds").asBoolean()).isTrue();

        Map<String, String> cont = Map.of("sku", "CONTINUE", "idempotencyKey", "spend-0003");
        assertThat(api.post("/api/v1/me/wallet/spend", cont, s.access()).body().get("wallet").get("gems").asInt()).isEqualTo(38);
        // Starter pack: gems once per token + remove-ads; a transfer moves the entitlement only.
        Session fresh = guest();
        Session reinstall = guest();
        Map<String, String> starter = Map.of("productId", "starter_pack", "purchaseToken", "test-valid-sp-" + UUID.randomUUID());
        JsonNode sp = api.post("/api/v1/purchases/google/verify", starter, fresh.access()).body();
        assertThat(sp.get("wallet").get("gems").asInt()).isEqualTo(80);
        assertThat(sp.get("entitlements").get("removeAds").asBoolean()).isTrue();
        JsonNode moved = api.post("/api/v1/purchases/google/verify", starter, reinstall.access()).body();
        assertThat(moved.get("wallet").get("gems").asInt()).isZero();
        assertThat(moved.get("entitlements").get("removeAds").asBoolean()).isTrue();

        assertThat(api.get("/api/v1/store/products", null).body()).hasSize(7);
    }

    @Test
    void refreshRotationAndReuseDetection() {
        Session s = guest();
        Api.Res r1 = api.post("/api/v1/auth/refresh", Map.of("refreshToken", s.refresh()), null);
        assertThat(r1.status()).isEqualTo(200);
        String rotated = r1.body().get("refreshToken").asText();
        assertThat(api.post("/api/v1/auth/refresh", Map.of("refreshToken", s.refresh()), null).status()).isEqualTo(401);
        // Reuse revoked the whole family, including the rotated token.
        assertThat(api.post("/api/v1/auth/refresh", Map.of("refreshToken", rotated), null).status()).isEqualTo(401);
    }

    @Test
    void firebaseLinkAndSignIn() {
        Session s = guest();
        String uid = "uid-" + UUID.randomUUID();
        Api.Res linked = api.post("/api/v1/auth/firebase", Map.of("idToken", "fake:" + uid), s.access());
        assertThat(linked.body().get("userId").asText()).isEqualTo(s.userId());
        Session device2 = guest();
        Api.Res signIn = api.post("/api/v1/auth/firebase", Map.of("idToken", "fake:" + uid), device2.access());
        assertThat(signIn.body().get("userId").asText()).isEqualTo(s.userId());
        assertThat(api.post("/api/v1/auth/firebase", Map.of("idToken", "bad"), null).status()).isEqualTo(401);
        assertThat(api.get("/api/v1/me/profile", s.access()).body().get("linked").asBoolean()).isTrue();
    }

    @Test
    void adminRequiresRoleAndReplacesPuzzleWithAudit() {
        Session s = guest();
        Map<String, JsonNode> d = daily();
        String old = d.get("SUDOKU").get("puzzleId").asText();
        String date = api.get("/api/v1/daily-challenge", null).body().get("date").asText();
        assertThat(api.post("/api/v1/admin/daily/" + date + "/SUDOKU/replace", Map.of("reason", "x"), s.access()).status())
                .isEqualTo(403);
        db.sql("update users set roles = 'USER,ADMIN' where id = :id").param("id", UUID.fromString(s.userId())).update();
        String adminToken = api.post("/api/v1/auth/refresh", Map.of("refreshToken", s.refresh()), null).body()
                .get("accessToken").asText();
        Api.Res replaced = api.post("/api/v1/admin/daily/" + date + "/SUDOKU/replace", Map.of("reason", "ambiguous"), adminToken);
        assertThat(replaced.status()).isEqualTo(200);
        assertThat(replaced.body().get("contentVersion").asInt()).isGreaterThan(1);
        assertThat(daily().get("SUDOKU").get("puzzleId").asText()).isNotEqualTo(old);
        assertThat(db.sql("select count(*) from audit_log where action = 'DAILY_REPLACE'").query(Long.class).single()).isPositive();
        Api.Res gone = api.post("/api/v1/attempts", Map.of("puzzleId", old, "idempotencyKey", "key-" + UUID.randomUUID()), adminToken);
        assertThat(gone.status()).isEqualTo(410);
    }

    @Test
    void validationLimitsAndAccountDeletion() {
        Session s = guest();
        Map<String, JsonNode> d = daily();
        String attemptId = attempt(s, d.get("QUEENS"));
        Api.Res bad = api.post("/api/v1/attempts/" + attemptId + "/submit",
                Map.of("submission", Map.of("queens", List.of()), "hintsUsed", 99, "clientDurationMs", 0), s.access());
        assertThat(bad.status()).isEqualTo(400);
        assertThat(bad.body().get("code").asText()).isEqualTo("VALIDATION_FAILED");
        assertThat(api.post("/api/v1/attempts", Map.of("puzzleId", UUID.randomUUID().toString()), s.access()).status())
                .isEqualTo(400);
        String huge = "{\"version\":0,\"data\":{\"x\":\"" + String.join("", Collections.nCopies(300_000, "a")) + "\"}}";
        assertThat(api.raw("PUT", "/api/v1/me/progress", huge, s.access()).status()).isEqualTo(413);
        assertThat(api.patch("/api/v1/me/preferences", Map.of("displayName", "<script>"), s.access()).status()).isEqualTo(400);
        assertThat(api.patch("/api/v1/me/preferences", Map.of("displayName", "Sri M", "reminderTime", "08:30"), s.access())
                .body().get("reminderTime").asText()).isEqualTo("08:30");

        assertThat(api.post("/api/v1/me/push-token", Map.of("token", "fcm-abc", "platform", "ANDROID"), s.access()).status())
                .isEqualTo(204);
        assertThat(api.delete("/api/v1/me", s.access()).status()).isEqualTo(204);
        Api.Res after = api.get("/api/v1/me/profile", s.access());
        assertThat(after.status()).isEqualTo(401);
        assertThat(after.body().get("code").asText()).isEqualTo("ACCOUNT_DELETED");
        assertThat(api.post("/api/v1/auth/refresh", Map.of("refreshToken", s.refresh()), null).status()).isEqualTo(401);
    }

    @Test
    void leaderboardTieBreakers() {
        Session me = guest();
        Session fast = guest();
        Session slowEarly = guest();
        Session slowLate = guest();
        JsonNode merge = daily().get("MERGE");
        String date = api.get("/api/v1/daily-challenge", null).body().get("date").asText();
        String myCode = api.get("/api/v1/me/profile", me.access()).body().get("friendCode").asText();
        Object[][] rows = {{fast, 500, 1000L, "10:00"}, {slowLate, 500, 2000L, "10:05"}, {slowEarly, 500, 2000L, "10:01"},
                {me, 900, 9000L, "11:00"}};
        for (Object[] r : rows) {
            Session s = (Session) r[0];
            api.post("/api/v1/me/friends", Map.of("friendCode", myCode), s.access());
            UUID attemptId = UUID.randomUUID();
            db.sql("insert into attempts (id, user_id, puzzle_id, idempotency_key, started_at) values (:id, :u, :p, :k, now())")
                    .param("id", attemptId).param("u", UUID.fromString(s.userId()))
                    .param("p", UUID.fromString(merge.get("puzzleId").asText())).param("k", "seed-" + attemptId).update();
            db.sql("""
                    insert into leaderboard_entries (challenge_date, game_type, user_id, attempt_id, score, duration_ms, submitted_at)
                    values (cast(:d as date), 'MERGE', :u, :a, :s, :ms, cast(:d || ' ' || :t as timestamptz))""")
                    .param("d", date).param("u", UUID.fromString(s.userId())).param("a", attemptId).param("s", r[1])
                    .param("ms", r[2]).param("t", (String) r[3]).update();
        }
        JsonNode lb = api.get("/api/v1/leaderboards/daily?gameType=MERGE&scope=FRIENDS&size=2&page=0", me.access()).body();
        assertThat(lb.get("total").asInt()).isEqualTo(4);
        assertThat(lb.get("entries")).hasSize(2);
        assertThat(lb.get("entries").get(0).get("userId").asText()).isEqualTo(me.userId());
        assertThat(lb.get("entries").get(1).get("userId").asText()).isEqualTo(fast.userId());
        JsonNode page2 = api.get("/api/v1/leaderboards/daily?gameType=MERGE&scope=FRIENDS&size=2&page=1", me.access()).body();
        assertThat(page2.get("entries").get(0).get("userId").asText()).isEqualTo(slowEarly.userId());
        assertThat(page2.get("entries").get(1).get("userId").asText()).isEqualTo(slowLate.userId());
        assertThat(page2.get("entries").get(1).get("rank").asInt()).isEqualTo(4);
        assertThat(lb.get("me").get("rank").asInt()).isEqualTo(1);
    }
}
