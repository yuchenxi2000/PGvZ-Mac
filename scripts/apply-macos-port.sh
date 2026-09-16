#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SOURCE_DIR="$PROJECT_ROOT/src/Lawn"
GAME_DIR=${1:-${PGVZ_GAME_DIR:-}}
GAME_BUILDS_FILE=${PGVZ_GAME_BUILDS_FILE:-"$PROJECT_ROOT/supported-game-builds.tsv"}
COMPAT_SOURCE="$PROJECT_ROOT/porting/DynamicHookGenCompat.cs"
COMPAT_DEST="$SOURCE_DIR/LawnMod/DynamicHookGenCompat.cs"

if [ -z "$GAME_DIR" ]; then
  echo "Usage: scripts/apply-macos-port.sh /path/to/PlantGirlsVsZombies" >&2
  echo "Alternatively set PGVZ_GAME_DIR." >&2
  exit 1
fi

if [ ! -f "$SOURCE_DIR/Lawn.csproj" ]; then
  echo "Decompiled project not found; run scripts/decompile-windows.sh first." >&2
  exit 1
fi

"$SCRIPT_DIR/verify-game.sh" "$GAME_DIR"
GAME_SHA256=$(shasum -a 256 "$GAME_DIR/Lawn.exe" | awk '{print $1}')
PATCH_NAME=$(awk -F '\t' -v hash="$GAME_SHA256" '
  $0 !~ /^#/ && $1 == hash { print $4; exit }
' "$GAME_BUILDS_FILE")
if [ -z "$PATCH_NAME" ]; then
  LATEST_PATCH_RECORD=$(awk -F '\t' '
    $0 !~ /^#/ && $4 != "" { version = $2; patch = $4 }
    END { if (patch != "") print version "\t" patch }
  ' "$GAME_BUILDS_FILE")
  if [ -z "$LATEST_PATCH_RECORD" ]; then
    echo "No macOS patches are registered in supported-game-builds.tsv." >&2
    exit 1
  fi
  LATEST_PATCH_VERSION=$(printf '%s\n' "$LATEST_PATCH_RECORD" | awk -F '\t' '{print $1}')
  PATCH_NAME=$(printf '%s\n' "$LATEST_PATCH_RECORD" | awk -F '\t' '{print $2}')
  echo "WARNING: no exact patch mapping for Lawn.exe SHA-256: $GAME_SHA256" >&2
  echo "Falling back to the latest registered patch: $PATCH_NAME ($LATEST_PATCH_VERSION)" >&2
fi
case "$PATCH_NAME" in
  *[!A-Za-z0-9._-]*)
    echo "Invalid patch name in supported-game-builds.tsv: $PATCH_NAME" >&2
    exit 1
    ;;
esac
PATCH_FILE="$PROJECT_ROOT/patches/$PATCH_NAME"
if [ ! -f "$PATCH_FILE" ]; then
  echo "Registered macOS patch is missing: $PATCH_FILE" >&2
  exit 1
fi
echo "Selected macOS patch: $PATCH_NAME"

if git -C "$PROJECT_ROOT" apply --check --directory=src/Lawn "$PATCH_FILE" 2>/dev/null; then
  git -C "$PROJECT_ROOT" apply --directory=src/Lawn "$PATCH_FILE"
elif git -C "$PROJECT_ROOT" apply --reverse --check --directory=src/Lawn "$PATCH_FILE" 2>/dev/null; then
  echo "macOS source patch was already applied."
else
  git -C "$PROJECT_ROOT" apply --check --directory=src/Lawn "$PATCH_FILE" || true
  echo "The macOS patch does not match this decompiled source tree." >&2
  echo "Use ilspycmd 8.2.0.7535, then review and adapt the patch for this game version." >&2
  echo "After successful build and smoke tests, record its hash in supported-game-builds.tsv." >&2
  exit 1
fi

cp "$COMPAT_SOURCE" "$COMPAT_DEST"
. "$SCRIPT_DIR/env.sh"
dotnet restore "$SOURCE_DIR/Lawn.csproj" --runtime osx-arm64
echo "macOS source port prepared: $SOURCE_DIR"
