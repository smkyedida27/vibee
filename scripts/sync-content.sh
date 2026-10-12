#!/usr/bin/env bash
# Copies shared puzzle content into the app and backend. `--check` fails on drift (used in CI).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGETS=("$ROOT/app/assets/content" "$ROOT/backend/src/main/resources/content")
for t in "${TARGETS[@]}"; do
  if [[ "${1:-}" == "--check" ]]; then
    diff -r "$ROOT/content" "$t" >/dev/null || { echo "Content drift in $t — run scripts/sync-content.sh"; exit 1; }
  else
    mkdir -p "$t" && cp "$ROOT"/content/* "$t"/
  fi
done
echo "content ok"
