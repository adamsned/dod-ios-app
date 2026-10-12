#!/usr/bin/env bash
# bin/verify.sh — one-shot local mirror of the CI "required" gates.
#
# Run this BEFORE every push. If it passes, CI's required gates pass too, so you
# never burn a CI cycle (or a code review) on a lint slip. It catches the sneaky
# one: swift-format's *formatter* and its *linter* can disagree, so formatting
# alone is not enough — CI runs the linter, and so does this.
#
# Usage:
#   ./bin/verify.sh              Full: format-fix, swift-format lint, SwiftLint, app build
#   ./bin/verify.sh --quick      Fast: format-fix + both lints only (skip the build)
#   ./bin/verify.sh --test PKG   Also run `swift test` for Packages/PKG
#
# Tip for the tight inner loop (seconds, not minutes):
#   xcrun swift test --package-path Packages/<the package you're editing>
set -euo pipefail
cd "$(dirname "$0")/.."

QUICK=0
TEST_PKG=""
while [ $# -gt 0 ]; do
    case "$1" in
        --quick) QUICK=1; shift ;;
        --test) TEST_PKG="${2:-}"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

# Pick up Homebrew (swift-format / swiftlint) + Xcode if a login shell didn't.
if command -v brew >/dev/null 2>&1; then eval "$(brew shellenv)"; fi
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

step() { printf '\n\033[1;36m▸ %s\033[0m\n' "$1"; }
ok() { printf '\033[1;32m✓ %s\033[0m\n' "$1"; }

# 1. Format (auto-fix), then LINT the format — CI's "Format check" runs the lint.
step "swift-format: format + lint (CI Format check)"
./bin/format.sh >/dev/null
swift-format lint --strict --recursive --configuration .swift-format \
    App AppTests Packages Widget LiveActivity
ok "swift-format clean"

# 2. SwiftLint — CI's "Lint" gate.
# The no-Xcode-toolchain Macs need swiftlint pointed at the CommandLineTools
# frameworks or it fails to load; on a full-Xcode Mac the var is harmless. CI
# runs bin/lint.sh directly (full Xcode, no shim needed).
step "SwiftLint --strict (CI Lint gate)"
DYLD_FRAMEWORK_PATH="${DYLD_FRAMEWORK_PATH:-/Library/Developer/CommandLineTools/usr/lib}" \
    ./bin/lint.sh
ok "SwiftLint clean"

# 3. Optional: unit tests for one package (fast, scoped).
if [ -n "$TEST_PKG" ]; then
    step "swift test — Packages/$TEST_PKG"
    xcrun swift test --package-path "Packages/$TEST_PKG"
    ok "$TEST_PKG tests pass"
fi

# 4. App build — the compile gate (slow; skip with --quick during iteration).
if [ "$QUICK" -eq 1 ]; then
    printf '\n\033[1;33m• skipped app build (--quick)\033[0m\n'
else
    step "iOS app build (xcodebuild)"
    if command -v xcodegen >/dev/null 2>&1; then xcodegen generate >/dev/null; fi
    xcodebuild build -scheme DODApp \
        -destination 'generic/platform=iOS Simulator' -quiet
    ok "app builds"
fi

printf '\n\033[1;32m✅ verify passed — safe to push.\033[0m\n'
