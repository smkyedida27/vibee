#!/usr/bin/env bash
# Post-deploy smoke test. Usage: scripts/smoke-test.sh https://api.example.com
# (/actuator/* is blocked at the ALB, so this exercises public API paths.)
set -euo pipefail
BASE="${1:?usage: smoke-test.sh <base-url>}"
fail() { echo "SMOKE FAIL: $*" >&2; exit 1; }

for i in $(seq 1 10); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/v1/games") && [ "$code" = 200 ] && break
  echo "waiting for API ($code)…"; sleep 6
done
[ "${code:-}" = 200 ] || fail "GET /api/v1/games -> ${code:-none}"

daily=$(curl -sf "$BASE/api/v1/daily-challenge") || fail "daily-challenge request failed"
count=$(printf '%s' "$daily" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["puzzles"]))') \
  || fail "daily-challenge payload not parseable"
[ "$count" -ge 5 ] || fail "daily challenge has $count puzzles (expected 5)"

token=$(curl -sf -X POST "$BASE/api/v1/auth/guest" -H 'Content-Type: application/json' \
  -d "{\"deviceId\":\"smoke-$(date +%s)\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["accessToken"])') \
  || fail "guest auth failed"
curl -sf "$BASE/api/v1/me/streak" -H "Authorization: Bearer $token" >/dev/null || fail "authorized read failed"

echo "smoke ok: $BASE"
