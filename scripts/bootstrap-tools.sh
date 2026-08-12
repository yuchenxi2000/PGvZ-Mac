#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
DOTNET_VERSION=6.0.428
ILSPY_VERSION=8.2.0.7535
DOTNET_DIR="$PROJECT_ROOT/.tools/dotnet"
ILSPY_DIR="$PROJECT_ROOT/.tools/ilspy"
TEMP_DIR=$(mktemp -d -t pgvz-tools.XXXXXX)

finish() {
  rm -rf "$TEMP_DIR"
}
trap finish EXIT INT TERM

case "$(uname -m)" in
  arm64) DOTNET_ARCH=arm64 ;;
  x86_64) DOTNET_ARCH=x64 ;;
  *)
    echo "Unsupported macOS architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

if [ ! -x "$DOTNET_DIR/dotnet" ]; then
  echo "Installing .NET SDK $DOTNET_VERSION into $DOTNET_DIR"
  curl --fail --location --silent --show-error \
    https://dot.net/v1/dotnet-install.sh \
    --output "$TEMP_DIR/dotnet-install.sh"
  sh "$TEMP_DIR/dotnet-install.sh" \
    --version "$DOTNET_VERSION" \
    --architecture "$DOTNET_ARCH" \
    --install-dir "$DOTNET_DIR"
fi

. "$SCRIPT_DIR/env.sh"
ACTUAL_DOTNET_VERSION=$(dotnet --version)
if [ "$ACTUAL_DOTNET_VERSION" != "$DOTNET_VERSION" ]; then
  echo "Expected .NET SDK $DOTNET_VERSION, found $ACTUAL_DOTNET_VERSION in $DOTNET_DIR" >&2
  exit 1
fi

if [ ! -x "$ILSPY_DIR/ilspycmd" ]; then
  mkdir -p "$ILSPY_DIR"
  dotnet tool install ilspycmd \
    --tool-path "$ILSPY_DIR" \
    --version "$ILSPY_VERSION"
fi

ACTUAL_ILSPY_VERSION=$(ilspycmd --version | sed -n 's/^ilspycmd: //p')
if [ "$ACTUAL_ILSPY_VERSION" != "$ILSPY_VERSION" ]; then
  echo "Expected ilspycmd $ILSPY_VERSION, found $ACTUAL_ILSPY_VERSION in $ILSPY_DIR" >&2
  exit 1
fi

echo "Toolchain ready: .NET $DOTNET_VERSION, ilspycmd $ILSPY_VERSION"
