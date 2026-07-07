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
