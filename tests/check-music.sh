#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LOG_FILE=${1:?Usage: tests/check-music.sh /path/to/game.log}

attempt=0
while [ "$attempt" -lt 30 ]; do
  if grep -q 'TitleScreen: GotFocus' "$LOG_FILE"; then
    break
  fi
  sleep 1
  attempt=$((attempt + 1))
done
if ! grep -q 'TitleScreen: GotFocus' "$LOG_FILE"; then
  cat "$LOG_FILE" >&2
  echo "Game did not reach the title screen." >&2
  exit 1
fi
if grep -E 'Failed to load (MO3 music|music) file' "$LOG_FILE"; then
  echo "Game reported a music loading failure." >&2
  exit 1
fi
python3 "$SCRIPT_DIR/websocket_smoke.py" "$(cat "$SCRIPT_DIR/mo3_smoke.py")" "None"
