#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$SCRIPT_DIR/env.sh"

GAME_DIR=${1:-${PGVZ_GAME_DIR:-}}
GAME_EXE="$GAME_DIR/Lawn.exe"
EXTRACTED="$PROJECT_ROOT/artifacts/extracted/windows"
SOURCE="$PROJECT_ROOT/src/Lawn"

if [ -z "$GAME_DIR" ]; then
  echo "Usage: scripts/decompile-windows.sh /path/to/PlantGirlsVsZombies" >&2
  echo "Alternatively set PGVZ_GAME_DIR." >&2
  exit 1
fi
if [ ! -x "$PROJECT_ROOT/.tools/ilspy/ilspycmd" ]; then
  echo "Missing ILSpy: $PROJECT_ROOT/.tools/ilspy/ilspycmd" >&2
  exit 1
fi

"$SCRIPT_DIR/verify-game.sh" "$GAME_DIR"
if [ ! -f "$GAME_EXE" ]; then
  echo "Missing game executable: $GAME_EXE" >&2
  exit 1
fi
if [ -e "$SOURCE" ]; then
  echo "Refusing to overwrite existing source directory: $SOURCE" >&2
  exit 1
fi

mkdir -p "$EXTRACTED" "$SOURCE"
ilspycmd --disable-updatecheck -d -o "$EXTRACTED" "$GAME_EXE"
ilspycmd --disable-updatecheck --nested-directories -p \
  -r "$EXTRACTED" -o "$SOURCE" "$EXTRACTED/Lawn.dll"

echo "Extracted bundle: $EXTRACTED"
echo "Decompiled source: $SOURCE"
