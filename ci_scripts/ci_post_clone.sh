#!/bin/sh

# Xcode Cloud post-clone hook.
#
# `DODApp.xcodeproj` is intentionally gitignored — it is generated from
# `project.yml` by XcodeGen, so it does not exist in a fresh clone. Xcode Cloud
# clones the repo and then archives `DODApp.xcodeproj`, so without this step the
# build fails with "Project DODApp.xcodeproj does not exist at the root of the
# repository." Generate it here, after clone and before the build resolves the
# project. (The GitHub Actions release workflow runs the same `xcodegen
# generate`; this brings Xcode Cloud to parity.)

set -e

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Xcode Cloud runners ship Homebrew. Install XcodeGen if it isn't already there.
if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi

# project.yml lives at the repository root; generate the project there.
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

echo "ci_post_clone: generated DODApp.xcodeproj via XcodeGen at $CI_PRIMARY_REPOSITORY_PATH"

# `DODApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
# is gitignored along with the rest of the generated `.xcodeproj` (see above),
# so a fresh XcodeGen-generated project has no resolved file at all. Xcode
# Cloud's Archive step runs with automatic package resolution DISABLED and
# fails outright — "a resolved file is required when automatic dependency
# resolution is disabled" — the first time the package graph changes (hit
# when GoogleSignIn-iOS and TelemetryDeck's SwiftSDK were added, since a
# resolved file was never present to update). Resolve explicitly here, in the
# post-clone hook, so Archive finds an already-current resolved file instead
# of needing to (and being disallowed from) resolving it itself.
#
# This step itself has been observed to fail intermittently on Xcode Cloud's
# runners (exit 74 — BSD EX_IOERR) while fetching package sources from GitHub,
# even though the identical command succeeds reliably outside that sandboxed
# network environment. Retry a few times before giving up, since a transient
# fetch hiccup here otherwise fails the entire Archive with no recourse but a
# manual rebuild.
resolve_attempt=1
until xcodebuild -resolvePackageDependencies -project DODApp.xcodeproj -scheme DODApp; do
  if [ "$resolve_attempt" -ge 3 ]; then
    echo "ci_post_clone: giving up resolving SwiftPM package dependencies after $resolve_attempt attempts" >&2
    exit 1
  fi
  echo "ci_post_clone: package resolution failed (attempt $resolve_attempt) — retrying in 15s"
  resolve_attempt=$((resolve_attempt + 1))
  sleep 15
done

echo "ci_post_clone: resolved SwiftPM package dependencies for DODApp.xcodeproj"
