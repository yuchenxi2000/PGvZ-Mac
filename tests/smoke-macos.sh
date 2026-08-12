#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
LOG_FILE=$(mktemp -t pgvz-mac-smoke.XXXXXX)
RUN_DIR="$PROJECT_ROOT/artifacts/run"
SMOKE_MOD="$RUN_DIR/cust/mods/runtime_detour_smoke.py"

finish() {
  if [ -n "${GAME_PID:-}" ] && kill -0 "$GAME_PID" 2>/dev/null; then
    kill "$GAME_PID" 2>/dev/null || true
    wait "$GAME_PID" 2>/dev/null || true
  fi
  rm -f "$SMOKE_MOD" "$RUN_DIR/runtime_detour_smoke.ok"
  rm -f "$LOG_FILE"
}
trap finish EXIT INT TERM

"$PROJECT_ROOT/scripts/prepare-runtime.sh" >/dev/null
cp "$SCRIPT_DIR/mods/runtime_detour_smoke.py" "$SMOKE_MOD"
rm -f "$RUN_DIR/runtime_detour_smoke.ok"
"$PROJECT_ROOT/scripts/run-macos.sh" >"$LOG_FILE" 2>&1 &
GAME_PID=$!

attempt=0
while [ "$attempt" -lt 30 ]; do
  if ! kill -0 "$GAME_PID" 2>/dev/null; then
    sed -n '1,200p' "$LOG_FILE" >&2
    echo "Game exited before smoke checks completed." >&2
    exit 1
  fi
  if python3 "$SCRIPT_DIR/websocket_smoke.py" 2>/dev/null; then
    if [ -d "$RUN_DIR/mods/pgvztool" ]; then
      python3 "$SCRIPT_DIR/websocket_smoke.py" "import pgvztool" "None"
    fi
    hook_attempt=0
    while [ "$hook_attempt" -lt 10 ] && [ ! -f "$RUN_DIR/runtime_detour_smoke.ok" ]; do
      sleep 1
      hook_attempt=$((hook_attempt + 1))
    done
    if [ ! -f "$RUN_DIR/runtime_detour_smoke.ok" ]; then
      sed -n '1,200p' "$LOG_FILE" >&2
      echo "RuntimeDetour hook did not run." >&2
      exit 1
    fi
    rg 'runtime_detour_smoke|TitleScreen: GotFocus' "$LOG_FILE" || true
    echo "macOS smoke checks passed."
    exit 0
  fi
  sleep 1
  attempt=$((attempt + 1))
done

sed -n '1,200p' "$LOG_FILE" >&2
echo "WebSocket did not become ready." >&2
exit 1
