#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GAME_DIR=${1:-${PGVZ_GAME_DIR:-}}

if [ -z "$GAME_DIR" ]; then
  echo "Usage: scripts/rebuild-macos-app.sh /path/to/PlantGirlsVsZombies" >&2
  echo "Run this from a clean clone without an existing src/Lawn directory." >&2
  exit 1
fi

"$SCRIPT_DIR/bootstrap-tools.sh"
"$SCRIPT_DIR/decompile-windows.sh" "$GAME_DIR"
"$SCRIPT_DIR/apply-macos-port.sh"
"$SCRIPT_DIR/package-app.sh" "$GAME_DIR"

echo "Native App ready: $SCRIPT_DIR/../dist/PlantGirlsVsZombies.app"
