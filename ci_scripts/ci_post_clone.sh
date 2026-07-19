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
# is the ONE exception carved out of `.gitignore`'s otherwise-blanket ignore of
# the generated `.xcodeproj` — it's committed to the repo directly. Xcode
# Cloud's Archive step runs with automatic package resolution DISABLED and
# requires this file to exist ahead of time ("a resolved file is required when
# automatic dependency resolution is disabled"); `xcodegen generate` above
# never touches a pre-existing file at this path (verified: survives a full
# regenerate byte-identical), so the committed copy persists straight through
# to Archive with no extra step needed.
#
# IMPORTANT — whoever adds/removes/bumps a package dependency (in `project.yml`
# or any `Package.swift`) MUST regenerate and commit an updated
# `Package.resolved` alongside that change, or Xcode Cloud will build against
# a stale dependency set.
#
# We ALSO attempt a fresh resolve here, best-effort, so the committed file
# stays current even if someone forgets the step above — but this attempt
# must never fail the whole build if it errors, or leave a corrupt/partial
# file behind if it fails partway through: it has been observed failing
# reliably (not just flakily — different exit codes and different triggering
# dependencies on different builds) inside Xcode Cloud's sandbox in a way that
# retrying doesn't fix, while the already-committed file works every time.
# Back it up first and restore on failure so a bad attempt can't leave Archive
# worse off than doing nothing.
resolved_file="DODApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
cp "$resolved_file" "$resolved_file.committed-backup"
if xcodebuild -resolvePackageDependencies -project DODApp.xcodeproj -scheme DODApp; then
  rm -f "$resolved_file.committed-backup"
else
  echo "ci_post_clone: best-effort package re-resolution failed — restoring the committed Package.resolved" >&2
  mv "$resolved_file.committed-backup" "$resolved_file"
fi

echo "ci_post_clone: DODApp.xcodeproj ready (committed Package.resolved in place)"
