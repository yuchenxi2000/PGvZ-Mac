#!/bin/sh
set -eu

RUNTIME_DIR=${1:-}
COMPAT_NAME=libSDL2-2.0.0.dylib

if [ -z "$RUNTIME_DIR" ] || [ ! -d "$RUNTIME_DIR" ]; then
  echo "Usage: scripts/link-sdl-compat.sh /path/to/runtime-directory" >&2
  exit 1
fi

SDL_TARGET=
for candidate in \
  libSDL2.dylib \
  runtimes/osx/native/libSDL2.dylib \
  runtimes/osx-arm64/native/libSDL2.dylib; do
  if [ -f "$RUNTIME_DIR/$candidate" ]; then
    SDL_TARGET=$candidate
    break
  fi
done

if [ -z "$SDL_TARGET" ]; then
  echo "MonoGame SDL library not found under: $RUNTIME_DIR" >&2
  exit 1
fi

if [ -d "$RUNTIME_DIR/$COMPAT_NAME" ]; then
  echo "Refusing to replace directory: $RUNTIME_DIR/$COMPAT_NAME" >&2
  exit 1
fi

rm -f "$RUNTIME_DIR/$COMPAT_NAME"
ln -s "$SDL_TARGET" "$RUNTIME_DIR/$COMPAT_NAME"
echo "SDL compatibility link: $COMPAT_NAME -> $SDL_TARGET"
