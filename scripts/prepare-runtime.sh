#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$SCRIPT_DIR/env.sh"

GAME_DIR=${1:-${PGVZ_GAME_DIR:-}}
BUILD_DIR="$PROJECT_ROOT/src/Lawn/bin/Debug/net6.0"
RUN_DIR="$PROJECT_ROOT/artifacts/run"

if [ -z "$GAME_DIR" ]; then
  echo "Usage: scripts/prepare-runtime.sh /path/to/PlantGirlsVsZombies" >&2
  echo "Alternatively set PGVZ_GAME_DIR." >&2
  exit 1
fi
if [ ! -d "$GAME_DIR/Content" ] || [ ! -d "$GAME_DIR/lib" ]; then
  echo "Game Content/lib directories not found under: $GAME_DIR" >&2
  exit 1
fi

dotnet build "$PROJECT_ROOT/src/Lawn/Lawn.csproj" --no-restore -v:minimal -m:1
mkdir -p "$RUN_DIR/cust/mods"
# These root-level files existed in the earliest prototype. MonoGame already stages
# the same libraries under runtimes/osx/native and loading both copies is unsafe.
rm -f "$BUILD_DIR/libSDL2.dylib" "$BUILD_DIR/libopenal.1.dylib" \
  "$RUN_DIR/libSDL2.dylib" "$RUN_DIR/libopenal.1.dylib"
cp -R "$BUILD_DIR/." "$RUN_DIR/"
cp "$PROJECT_ROOT/config.macos.json" "$RUN_DIR/config.json"
"$SCRIPT_DIR/link-sdl-compat.sh" "$RUN_DIR"

if [ ! -e "$RUN_DIR/Content" ]; then
  ln -s "$GAME_DIR/Content" "$RUN_DIR/Content"
fi
if [ ! -e "$RUN_DIR/lib" ]; then
  ln -s "$GAME_DIR/lib" "$RUN_DIR/lib"
fi

echo "Runtime prepared: $RUN_DIR"
