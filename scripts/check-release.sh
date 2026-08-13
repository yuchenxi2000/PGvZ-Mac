#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

cd "$PROJECT_ROOT"

for required in BUILDING.md README.md patches/macos-port.patch \
  supported-game-builds.tsv \
  porting/DynamicHookGenCompat.cs porting/NoWindowIcon.dat \
  packaging/icon/AppIcon-Modern.png; do
  if [ ! -f "$required" ]; then
    echo "Missing required release file: $required" >&2
    exit 1
  fi
done

BAD_TRACKED=$(git ls-files | \
  grep -E '(^|/)(src|artifacts|dist|\.tools|local|game-install|user-data)/|\.(exe|dll|pdb|mdb|dylib|so|ico|bmp)$|AppIcon-original\.png$' || true)
if [ -n "$BAD_TRACKED" ]; then
  echo "Refusing release because proprietary/generated paths are tracked:" >&2
  echo "$BAD_TRACKED" >&2
  exit 1
fi

for ignored in src/Lawn/Lawn.csproj artifacts/extracted/windows/Lawn.dll \
  dist/PlantGirlsVsZombies.app local/PlantGirlsVsZombies/Lawn.exe \
  packaging/icon/AppIcon-original.png; do
  if ! git check-ignore -q "$ignored"; then
    echo "Expected path is not ignored: $ignored" >&2
    exit 1
  fi
done

if git ls-files | grep -q .; then
  if git grep -n -E '/Users/[^/]+/|Bottles/Win11|C:\\Program Files' -- . \
    ':!BUILDING.md' ':!scripts/check-release.sh' >/dev/null 2>&1; then
    echo "A tracked file contains a machine-specific absolute path." >&2
    git grep -n -E '/Users/[^/]+/|Bottles/Win11|C:\\Program Files' -- . \
      ':!BUILDING.md' ':!scripts/check-release.sh' >&2 || true
    exit 1
  fi
else
  echo "Warning: no files are tracked yet; rerun after git add." >&2
fi

echo "Release tree check passed. Review git status before publishing."
