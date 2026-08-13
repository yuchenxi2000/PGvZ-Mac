#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
GAME_DIR=${1:-${PGVZ_GAME_DIR:-}}
GAME_BUILDS_FILE=${PGVZ_GAME_BUILDS_FILE:-"$PROJECT_ROOT/supported-game-builds.tsv"}

if [ -z "$GAME_DIR" ]; then
  echo "Usage: scripts/verify-game.sh /path/to/PlantGirlsVsZombies" >&2
  exit 1
fi

if [ ! -f "$GAME_DIR/Lawn.exe" ]; then
  echo "Missing required game executable: $GAME_DIR/Lawn.exe" >&2
  exit 1
fi
for required_dir in Content lib; do
  if [ ! -d "$GAME_DIR/$required_dir" ]; then
    echo "Missing required game directory: $GAME_DIR/$required_dir" >&2
    exit 1
  fi
done
if [ ! -f "$GAME_BUILDS_FILE" ]; then
  echo "Missing supported game builds file: $GAME_BUILDS_FILE" >&2
  exit 1
fi

ACTUAL_LAWN_SHA256=$(shasum -a 256 "$GAME_DIR/Lawn.exe" | awk '{print $1}')
ACTUAL_LAWN_SIZE=$(stat -f '%z' "$GAME_DIR/Lawn.exe" 2>/dev/null || wc -c <"$GAME_DIR/Lawn.exe" | tr -d ' ')
MATCH=$(awk -F '\t' -v hash="$ACTUAL_LAWN_SHA256" '
  $0 !~ /^#/ && $1 == hash { print $2 "\t" $3; exit }
' "$GAME_BUILDS_FILE")

if [ -n "$MATCH" ]; then
  GAME_VERSION=$(printf '%s\n' "$MATCH" | awk -F '\t' '{print $1}')
  RECORDED_SIZE=$(printf '%s\n' "$MATCH" | awk -F '\t' '{print $2}')
  echo "Recognized game build: $GAME_VERSION"
  echo "Lawn.exe SHA-256: $ACTUAL_LAWN_SHA256"
  if [ -n "$RECORDED_SIZE" ] && [ "$ACTUAL_LAWN_SIZE" != "$RECORDED_SIZE" ]; then
    echo "Warning: manifest size is $RECORDED_SIZE bytes, actual size is $ACTUAL_LAWN_SIZE bytes." >&2
  fi
else
  echo "" >&2
  echo "WARNING: unrecognized Lawn.exe build; continuing for compatibility testing." >&2
  echo "Lawn.exe size:    $ACTUAL_LAWN_SIZE bytes" >&2
  echo "Lawn.exe SHA-256: $ACTUAL_LAWN_SHA256" >&2
  echo "The macOS patch may not apply to this version. Review decompilation and run all smoke tests before adding it to supported-game-builds.tsv." >&2
  echo "" >&2
fi

echo "Game installation structure verified: $GAME_DIR"
