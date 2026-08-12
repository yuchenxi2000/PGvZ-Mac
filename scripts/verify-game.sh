#!/bin/sh
set -eu

GAME_DIR=${1:-${PGVZ_GAME_DIR:-}}
EXPECTED_LAWN_SHA256=f23085f08ccaabb9019356a4316660806b487620b3d55c65e73e4af9b1514c41

if [ -z "$GAME_DIR" ]; then
  echo "Usage: scripts/verify-game.sh /path/to/PlantGirlsVsZombies" >&2
  exit 1
fi

for required in Lawn.exe Content lib; do
  if [ ! -e "$GAME_DIR/$required" ]; then
    echo "Missing required game file or directory: $GAME_DIR/$required" >&2
    exit 1
  fi
done

ACTUAL_LAWN_SHA256=$(shasum -a 256 "$GAME_DIR/Lawn.exe" | awk '{print $1}')
if [ "$ACTUAL_LAWN_SHA256" != "$EXPECTED_LAWN_SHA256" ]; then
  echo "Unsupported Lawn.exe build." >&2
  echo "Expected SHA-256: $EXPECTED_LAWN_SHA256" >&2
  echo "Actual SHA-256:   $ACTUAL_LAWN_SHA256" >&2
  echo "The source patch is version-specific; do not force it onto another build." >&2
  exit 1
fi

echo "Game installation verified: $GAME_DIR"
