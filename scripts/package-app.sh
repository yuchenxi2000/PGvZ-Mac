#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$SCRIPT_DIR/env.sh"

GAME_DIR=${1:-${PGVZ_GAME_DIR:-}}
PUBLISH_DIR="$PROJECT_ROOT/artifacts/publish/osx-arm64"
APP_DIR="$PROJECT_ROOT/dist/PlantGirlsVsZombies.app"
TEMP_ROOT=$(mktemp -d -t pgvz-app.XXXXXX)
TEMP_APP="$TEMP_ROOT/PlantGirlsVsZombies.app"
CONTENTS="$TEMP_APP/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
ICON_SOURCE="$PROJECT_ROOT/packaging/icon/AppIcon-Modern.png"

finish() {
  rm -rf "$TEMP_ROOT"
}
trap finish EXIT INT TERM

if [ -z "$GAME_DIR" ]; then
  echo "Usage: scripts/package-app.sh /path/to/PlantGirlsVsZombies" >&2
  echo "Alternatively set PGVZ_GAME_DIR." >&2
  exit 1
fi
if [ ! -d "$GAME_DIR/Content" ] || [ ! -d "$GAME_DIR/lib" ]; then
  echo "Game Content/lib directories not found under: $GAME_DIR" >&2
  exit 1
fi

if [ ! -f "$ICON_SOURCE" ]; then
  echo "Modern macOS icon source not found: $ICON_SOURCE" >&2
  exit 1
fi

dotnet publish "$PROJECT_ROOT/src/Lawn/Lawn.csproj" \
  --configuration Release \
  --runtime osx-arm64 \
  --self-contained true \
  --output "$PUBLISH_DIR" \
  -p:PublishAot=false \
  -p:PublishTrimmed=false \
  -p:PublishReadyToRun=false \
  -p:DebugType=None \
  -p:DebugSymbols=false \
  -v:minimal

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$PROJECT_ROOT/dist"
cp -R "$PUBLISH_DIR/." "$MACOS_DIR/"
"$SCRIPT_DIR/link-sdl-compat.sh" "$MACOS_DIR"
cp "$PROJECT_ROOT/packaging/Info.plist" "$CONTENTS/Info.plist"
cp "$PROJECT_ROOT/config.macos.json" "$RESOURCES_DIR/config.json"
ditto "$GAME_DIR/Content" "$RESOURCES_DIR/Content"
ditto "$GAME_DIR/lib" "$RESOURCES_DIR/lib"

ICONSET_DIR="$TEMP_ROOT/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_64x64.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$ICON_SOURCE" "$ICONSET_DIR/icon_1024x1024.png"
perl "$PROJECT_ROOT/scripts/build-icns.pl" \
  "$ICONSET_DIR" "$RESOURCES_DIR/AppIcon.icns"

chmod +x "$MACOS_DIR/Lawn"
plutil -lint "$CONTENTS/Info.plist"
xattr -cr "$TEMP_APP"
codesign --force --deep --sign - "$TEMP_APP"
codesign --verify --deep --strict "$TEMP_APP"

rm -rf "$APP_DIR"
mv "$TEMP_APP" "$APP_DIR"
echo "App packaged: $APP_DIR"
