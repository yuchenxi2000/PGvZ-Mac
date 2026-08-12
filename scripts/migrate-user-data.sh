#!/bin/sh
set -eu

SOURCE_DIR=${1:-}
DEST_DIR="$HOME/Library/Application Support/ZBC/PlantGirlsVsZombies"

if [ -z "$SOURCE_DIR" ]; then
  echo "Usage: scripts/migrate-user-data.sh /path/to/windows/AppData/Roaming/ZBC/PlantGirlsVsZombies" >&2
  exit 1
fi
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Windows user-data directory not found: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
for name in docs mods cust user_config.json; do
  if [ ! -e "$SOURCE_DIR/$name" ]; then
    continue
  fi
  if [ -e "$DEST_DIR/$name" ]; then
    echo "Keeping existing: $DEST_DIR/$name"
    continue
  fi
  cp -R "$SOURCE_DIR/$name" "$DEST_DIR/$name"
  echo "Migrated: $name"
done

echo "User data ready: $DEST_DIR"
