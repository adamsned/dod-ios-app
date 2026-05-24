#!/usr/bin/env bash
# Format all Swift source under App/ and Packages/ using swift-format.
# Constitution §10: pre-commit and CI both run this.

set -euo pipefail

if ! command -v swift-format >/dev/null 2>&1; then
    echo "swift-format not found. Install with: brew install swift-format" >&2
    exit 1
fi

cd "$(dirname "$0")/.."

# --in-place + --recursive across the tree, skipping generated and build dirs.
swift-format format --in-place --recursive \
    --configuration .swift-format \
    App \
    AppTests \
    Packages

echo "swift-format: done."
