#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
. "$SCRIPT_DIR/env.sh"

RUN_DIR="$PROJECT_ROOT/artifacts/run"
if [ ! -f "$RUN_DIR/Lawn.dll" ]; then
  echo "Runtime is missing; run scripts/prepare-runtime.sh first." >&2
  exit 1
fi

cd "$RUN_DIR"
exec dotnet Lawn.dll "$@"
