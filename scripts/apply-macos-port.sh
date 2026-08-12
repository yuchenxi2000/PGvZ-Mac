#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SOURCE_DIR="$PROJECT_ROOT/src/Lawn"
PATCH_FILE="$PROJECT_ROOT/patches/macos-port.patch"
COMPAT_SOURCE="$PROJECT_ROOT/porting/DynamicHookGenCompat.cs"
COMPAT_DEST="$SOURCE_DIR/LawnMod/DynamicHookGenCompat.cs"

if [ ! -f "$SOURCE_DIR/Lawn.csproj" ]; then
  echo "Decompiled project not found; run scripts/decompile-windows.sh first." >&2
  exit 1
fi

if git -C "$PROJECT_ROOT" apply --check --directory=src/Lawn "$PATCH_FILE" 2>/dev/null; then
  git -C "$PROJECT_ROOT" apply --directory=src/Lawn "$PATCH_FILE"
elif git -C "$PROJECT_ROOT" apply --reverse --check --directory=src/Lawn "$PATCH_FILE" 2>/dev/null; then
  echo "macOS source patch was already applied."
else
  git -C "$PROJECT_ROOT" apply --check --directory=src/Lawn "$PATCH_FILE" || true
  echo "The macOS patch does not match this decompiled source tree." >&2
  echo "Verify the Lawn.exe SHA-256 and use ilspycmd 8.2.0.7535." >&2
  exit 1
fi

cp "$COMPAT_SOURCE" "$COMPAT_DEST"
. "$SCRIPT_DIR/env.sh"
dotnet restore "$SOURCE_DIR/Lawn.csproj" --runtime osx-arm64
echo "macOS source port prepared: $SOURCE_DIR"
