#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
TEMP_ROOT=$(mktemp -d -t pgvz-verify-test.XXXXXX)
GAME_DIR="$TEMP_ROOT/game"
MANIFEST="$TEMP_ROOT/builds.tsv"

finish() {
  rm -rf "$TEMP_ROOT"
}
trap finish EXIT INT TERM

mkdir -p "$GAME_DIR/Content" "$GAME_DIR/lib"
printf 'synthetic Lawn executable\n' >"$GAME_DIR/Lawn.exe"
HASH=$(shasum -a 256 "$GAME_DIR/Lawn.exe" | awk '{print $1}')
SIZE=$(stat -f '%z' "$GAME_DIR/Lawn.exe" 2>/dev/null || wc -c <"$GAME_DIR/Lawn.exe" | tr -d ' ')

printf '# SHA-256\tversion\tsize\tpatch\n%s\ttest-version\t%s\ttest.patch\n' "$HASH" "$SIZE" >"$MANIFEST"
KNOWN_OUTPUT=$(PGVZ_GAME_BUILDS_FILE="$MANIFEST" \
  "$PROJECT_ROOT/scripts/verify-game.sh" "$GAME_DIR" 2>&1)
printf '%s\n' "$KNOWN_OUTPUT" | grep -q 'Recognized game build: test-version'
printf '%s\n' "$KNOWN_OUTPUT" | grep -q 'macOS source patch: test.patch'

printf '# no recognized builds\n' >"$MANIFEST"
UNKNOWN_OUTPUT=$(PGVZ_GAME_BUILDS_FILE="$MANIFEST" \
  "$PROJECT_ROOT/scripts/verify-game.sh" "$GAME_DIR" 2>&1)
printf '%s\n' "$UNKNOWN_OUTPUT" | grep -q 'WARNING: unrecognized Lawn.exe build; continuing'
printf '%s\n' "$UNKNOWN_OUTPUT" | grep -q "$HASH"

rmdir "$GAME_DIR/lib"
if PGVZ_GAME_BUILDS_FILE="$MANIFEST" \
  "$PROJECT_ROOT/scripts/verify-game.sh" "$GAME_DIR" >/dev/null 2>&1; then
  echo "Verification unexpectedly accepted an incomplete installation." >&2
  exit 1
fi

echo "Game verification tests passed."
