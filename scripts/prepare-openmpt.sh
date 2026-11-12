#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
RUNTIME_DIR=${1:?Usage: scripts/prepare-openmpt.sh /path/to/runtime}
VERSION=0.8.10
ARCHIVE_NAME="libopenmpt-$VERSION+release.makefile.tar.gz"
ARCHIVE="$PROJECT_ROOT/.tools/downloads/$ARCHIVE_NAME"
SOURCE_DIR="$PROJECT_ROOT/.tools/libopenmpt-$VERSION+release"
SHA256=95073a10d33d0ed4352f41b68edccb9636002d2626f9fd2e00b191fcaabdd876
LIBRARY="$SOURCE_DIR/bin/libopenmpt.so"

if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  echo "libopenmpt packaging requires an Apple Silicon Mac." >&2
  exit 1
fi
mkdir -p "$PROJECT_ROOT/.tools/downloads"
if [ ! -f "$ARCHIVE" ]; then
  curl --fail --location --silent --show-error \
    "https://lib.openmpt.org/files/libopenmpt/src/$ARCHIVE_NAME" \
    --output "$ARCHIVE.tmp"
  mv "$ARCHIVE.tmp" "$ARCHIVE"
fi
printf '%s  %s\n' "$SHA256" "$ARCHIVE" | shasum -a 256 --check --status
if [ ! -d "$SOURCE_DIR" ]; then
  tar -xzf "$ARCHIVE" -C "$PROJECT_ROOT/.tools"
fi

# Use the SDK matching the selected Xcode tools. Built-in miniz, minimp3 and
# stb_vorbis keep MO3 decoding independent of Homebrew and external codecs.
SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export SDKROOT
make -C "$SOURCE_DIR" -j4 \
  CONFIG=macos ARCH=arm64 MACOSX_VERSION_MIN=11.0 STDCXX=c++17 STDC=c17 \
  PKG_CONFIG=false SHARED_LIB=1 STATIC_LIB=0 EXAMPLES=0 OPENMPT123=0 TEST=0 \
  NO_ZLIB=1 NO_MPG123=1 NO_OGG=1 NO_VORBIS=1 NO_VORBISFILE=1 \
  NO_PORTAUDIO=1 NO_PORTAUDIOCPP=1 NO_SDL2=1 NO_SDL=1 NO_FLAC=1 \
  NO_SNDFILE=1 NO_PULSEAUDIO=1 bin/libopenmpt.so

mkdir -p "$RUNTIME_DIR/licenses/libopenmpt"
cp "$LIBRARY" "$RUNTIME_DIR/libopenmpt.dylib"
install_name_tool -id '@loader_path/libopenmpt.dylib' "$RUNTIME_DIR/libopenmpt.dylib"
lipo "$RUNTIME_DIR/libopenmpt.dylib" -verify_arch arm64
# Reject accidental build-machine dependencies before signing/packaging.
otool -L "$RUNTIME_DIR/libopenmpt.dylib" | awk '
  NR > 1 && $1 !~ /^(@loader_path\/libopenmpt.dylib|\/usr\/lib\/|\/System\/Library\/)/ { bad = 1; print }
  END { exit bad }
'
cp "$SOURCE_DIR/LICENSE" "$RUNTIME_DIR/licenses/libopenmpt/LICENSE.txt"
cp "$SOURCE_DIR/src/mpt/LICENSE.BSD-3-Clause.txt" "$RUNTIME_DIR/licenses/libopenmpt/mpt-BSD-3-Clause.txt"
cp "$SOURCE_DIR/src/mpt/LICENSE.BSL-1.0.txt" "$RUNTIME_DIR/licenses/libopenmpt/mpt-BSL-1.0.txt"
cp "$SOURCE_DIR/include/miniz/LICENSE" "$RUNTIME_DIR/licenses/libopenmpt/miniz.txt"
cp "$SOURCE_DIR/include/minimp3/LICENSE" "$RUNTIME_DIR/licenses/libopenmpt/minimp3.txt"
sed -n '/^ALTERNATIVE A - MIT License/,$p' "$SOURCE_DIR/include/stb_vorbis/stb_vorbis.c" \
  > "$RUNTIME_DIR/licenses/libopenmpt/stb_vorbis.txt"
codesign --force --sign - "$RUNTIME_DIR/libopenmpt.dylib"
echo "MO3 decoder prepared: $RUNTIME_DIR/libopenmpt.dylib"
