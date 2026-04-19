#!/bin/bash
# Generate test TIFF files for visual testing with the Tiffen UI.
# Usage: ./tools/generate-test-tiffs.sh [output-directory]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$REPO_ROOT/test-images}"

echo "Compiling generator..."
clang -fobjc-arc -framework Foundation \
    -I/opt/homebrew/include -L/opt/homebrew/lib -ltiff -lz \
    "$SCRIPT_DIR/generate-test-tiffs.m" \
    -o /tmp/generate-test-tiffs

echo ""
/tmp/generate-test-tiffs "$OUTPUT_DIR"
rm -f /tmp/generate-test-tiffs
