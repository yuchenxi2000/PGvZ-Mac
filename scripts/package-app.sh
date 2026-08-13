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
ASSEMBLY_INFO="$PROJECT_ROOT/src/Lawn/Properties/AssemblyInfo.cs"

finish() {
  rm -rf "$TEMP_ROOT"
}
trap finish EXIT INT TERM

if [ -z "$GAME_DIR" ]; then
  echo "Usage: scripts/package-app.sh /path/to/PlantGirlsVsZombies" >&2
  echo "Alternatively set PGVZ_GAME_DIR." >&2
  exit 1
fi
"$SCRIPT_DIR/verify-game.sh" "$GAME_DIR"
if [ ! -f "$ASSEMBLY_INFO" ]; then
  echo "Assembly metadata not found: $ASSEMBLY_INFO" >&2
  echo "Run scripts/decompile-windows.sh before packaging." >&2
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

GAME_FILE_VERSION=$(awk -F '"' '/AssemblyFileVersion\("/ { print $2; exit }' "$ASSEMBLY_INFO")
GAME_INFO_VERSION=$(awk -F '"' '/AssemblyInformationalVersion\("/ { print $2; exit }' "$ASSEMBLY_INFO")
GAME_SHORT_VERSION=$(printf '%s\n' "$GAME_FILE_VERSION" | awk -F '.' '
  NF >= 3 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ {
    print $1 "." $2 "." $3
  }
')
GAME_BUILD_VERSION=$(printf '%s\n' "$GAME_FILE_VERSION" | awk -F '.' '
  NF >= 3 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ &&
  (NF < 4 || $4 ~ /^[0-9]+$/) {
    revision = (NF >= 4 ? $4 : 0)
    printf "%d%02d%02d%02d\n", $1, $2, $3, revision
  }
')
if [ -z "$GAME_SHORT_VERSION" ] || [ -z "$GAME_BUILD_VERSION" ]; then
  echo "Could not derive a macOS bundle version from AssemblyFileVersion: $GAME_FILE_VERSION" >&2
  exit 1
fi
if [ -z "$GAME_INFO_VERSION" ]; then
  GAME_INFO_VERSION=$GAME_SHORT_VERSION
fi
LAWN_SHA256=$(shasum -a 256 "$GAME_DIR/Lawn.exe" | awk '{print $1}')
plutil -replace CFBundleShortVersionString -string "$GAME_SHORT_VERSION" "$CONTENTS/Info.plist"
plutil -replace CFBundleVersion -string "$GAME_BUILD_VERSION" "$CONTENTS/Info.plist"
plutil -replace PGVZGameVersion -string "$GAME_INFO_VERSION" "$CONTENTS/Info.plist"
plutil -replace PGVZLawnSHA256 -string "$LAWN_SHA256" "$CONTENTS/Info.plist"

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
echo "App packaged: $APP_DIR (game $GAME_INFO_VERSION)"
