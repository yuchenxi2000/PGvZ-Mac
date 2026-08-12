#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
APP_BINARY="$PROJECT_ROOT/dist/PlantGirlsVsZombies.app/Contents/MacOS/Lawn"
DATA_DIR="$HOME/Library/Application Support/ZBC/PlantGirlsVsZombies"
SMOKE_MOD="$DATA_DIR/cust/mods/runtime_detour_smoke.py"
MARKER="$DATA_DIR/runtime_detour_smoke.ok"
LOG_FILE=$(mktemp -t pgvz-app-smoke.XXXXXX)

finish() {
  if [ -n "${GAME_PID:-}" ] && kill -0 "$GAME_PID" 2>/dev/null; then
    kill "$GAME_PID" 2>/dev/null || true
    wait "$GAME_PID" 2>/dev/null || true
  fi
  rm -f "$SMOKE_MOD" "$MARKER" "$LOG_FILE"
}
trap finish EXIT INT TERM

if [ ! -x "$APP_BINARY" ]; then
  echo "Packaged App is missing; run scripts/package-app.sh first." >&2
  exit 1
fi
if [ -e "$SMOKE_MOD" ]; then
  echo "Refusing to overwrite existing smoke module: $SMOKE_MOD" >&2
  exit 1
fi

mkdir -p "$DATA_DIR/cust/mods"
cp "$SCRIPT_DIR/mods/runtime_detour_smoke.py" "$SMOKE_MOD"
rm -f "$MARKER"
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
