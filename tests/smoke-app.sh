#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
APP_BINARY="${PGVZ_APP_PATH:-$PROJECT_ROOT/dist/PlantGirlsVsZombies.app}/Contents/MacOS/Lawn"
DATA_DIR="$HOME/Library/Application Support/ZBC/PlantGirlsVsZombies"
SMOKE_MOD="$DATA_DIR/cust/mods/runtime_detour_smoke.py"
MARKER="$DATA_DIR/runtime_detour_smoke.ok"
LOG_FILE=$(mktemp -t pgvz-app-smoke.XXXXXX)
CONFIG_BACKUP=$(mktemp -t pgvz-app-config.XXXXXX)
CONFIG_FILE="$DATA_DIR/user_config.json"
CONFIG_EXISTED=0
SMOKE_INSTALLED=0

finish() {
  if [ -n "${GAME_PID:-}" ] && kill -0 "$GAME_PID" 2>/dev/null; then
    kill "$GAME_PID" 2>/dev/null || true
    wait "$GAME_PID" 2>/dev/null || true
  fi
  if [ "$SMOKE_INSTALLED" = 1 ]; then
    rm -f "$SMOKE_MOD" "$MARKER"
    if [ "$CONFIG_EXISTED" = 1 ]; then
      cp -p "$CONFIG_BACKUP" "$CONFIG_FILE"
    else
      rm -f "$CONFIG_FILE"
    fi
  fi
  rm -f "$LOG_FILE" "$CONFIG_BACKUP"
}
trap finish EXIT INT TERM

if [ ! -x "$APP_BINARY" ]; then
  echo "Packaged App is missing; run scripts/package-app.sh first." >&2
  exit 1
fi
if [ -e "$SMOKE_MOD" ] || [ -L "$SMOKE_MOD" ] || [ -e "$MARKER" ] || [ -L "$MARKER" ]; then
  echo "Refusing to overwrite existing smoke module or marker." >&2
  exit 1
fi

mkdir -p "$DATA_DIR/cust/mods"
if [ -e "$CONFIG_FILE" ] || [ -L "$CONFIG_FILE" ]; then
  cp -p "$CONFIG_FILE" "$CONFIG_BACKUP"
  CONFIG_EXISTED=1
fi
cp "$SCRIPT_DIR/mods/runtime_detour_smoke.py" "$SMOKE_MOD"
SMOKE_INSTALLED=1
"$APP_BINARY" >"$LOG_FILE" 2>&1 &
GAME_PID=$!

attempt=0
while [ "$attempt" -lt 45 ]; do
  if ! kill -0 "$GAME_PID" 2>/dev/null; then
    sed -n '1,240p' "$LOG_FILE" >&2
    echo "Packaged App exited before checks completed." >&2
    exit 1
  fi
  if python3 "$SCRIPT_DIR/websocket_smoke.py" 2>/dev/null; then
    python3 "$SCRIPT_DIR/websocket_smoke.py" "import System" "None"
    python3 "$SCRIPT_DIR/websocket_smoke.py" \
      "System.Type.GetType('MonoGame.IMEHelper.Sdl, MonoGame.IMEHelper').GetField('NativeLibrary').GetValue(None) != System.IntPtr.Zero" \
      "True"
    if [ -d "$DATA_DIR/mods/pgvztool" ]; then
      python3 "$SCRIPT_DIR/websocket_smoke.py" "import pgvztool" "None"
    fi
    hook_attempt=0
    while [ "$hook_attempt" -lt 10 ] && [ ! -f "$MARKER" ]; do
      sleep 1
      hook_attempt=$((hook_attempt + 1))
    done
    if [ ! -f "$MARKER" ]; then
      sed -n '1,240p' "$LOG_FILE" >&2
      echo "RuntimeDetour hook did not run in packaged App." >&2
      exit 1
    fi
    "$SCRIPT_DIR/check-music.sh" "$LOG_FILE"
    python3 "$SCRIPT_DIR/websocket_smoke.py" "import Sexy; Sexy.SexyAppBase.XnaGame.Exit()" "None"
    exit_attempt=0
    while [ "$exit_attempt" -lt 10 ] && kill -0 "$GAME_PID" 2>/dev/null; do
      sleep 1
      exit_attempt=$((exit_attempt + 1))
    done
    rg 'runtime_detour_smoke|TitleScreen: GotFocus' "$LOG_FILE" || true
    echo "Packaged App smoke checks passed."
    exit 0
  fi
  sleep 1
  attempt=$((attempt + 1))
done

sed -n '1,240p' "$LOG_FILE" >&2
echo "Packaged App WebSocket did not become ready." >&2
exit 1
