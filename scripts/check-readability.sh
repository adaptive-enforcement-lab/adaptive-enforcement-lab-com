#!/bin/bash
# Check documentation readability using the readability CLI
# Downloads binary if not present, then runs analysis

set -e

READABILITY_VERSION="0.3.1"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/readability"
BINARY="$CACHE_DIR/readability"

# Detect platform
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
esac

# Download binary if not present or wrong version
download_binary() {
  mkdir -p "$CACHE_DIR"

  local url="https://github.com/adaptive-enforcement-lab/readability/releases/download/${READABILITY_VERSION}/readability_${OS}_${ARCH}.tar.gz"
  local extracted_name="readability_${OS}_${ARCH}"

  echo "Downloading readability v${READABILITY_VERSION}..."
  curl -sL "$url" | tar -xz -C "$CACHE_DIR"
  mv "$CACHE_DIR/$extracted_name" "$BINARY"
  chmod +x "$BINARY"
}

# Check if binary exists and is correct version
if [ ! -x "$BINARY" ]; then
  download_binary
else
  CURRENT_VERSION=$("$BINARY" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
  if [ "$CURRENT_VERSION" != "$READABILITY_VERSION" ]; then
    download_binary
  fi
fi

# Run readability check (auto-detects .readability.yml in repo root)
exec "$BINARY" docs/ --check
