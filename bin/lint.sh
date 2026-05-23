#!/usr/bin/env bash
# Run SwiftLint in strict mode. Warnings fail.
# Constitution §10.

set -euo pipefail

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "swiftlint not found. Install with: brew install swiftlint" >&2
    exit 1
fi

cd "$(dirname "$0")/.."

swiftlint --strict --config .swiftlint.yml
