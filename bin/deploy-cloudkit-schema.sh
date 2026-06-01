#!/usr/bin/env bash
# Promote the Dutch Oven Daddy CloudKit schema Development -> Production.
#
# This is the manual / on-demand counterpart to the automatic promotion the
# release pipeline runs (the deploy-cloudkit-schema job in
# .github/workflows/release.yml). Use this when you want to deploy the schema
# WITHOUT shipping a TestFlight build - in particular the very first time, to
# seed Production before the CLOUDKIT_MANAGEMENT_TOKEN secret is even added, or
# any time CI's best-effort post-step warned that the promotion failed.
#
# WHY THIS MATTERS (DUT-6 cause #1). NSPersistentCloudKitContainer auto-creates
# the CD_* record types ONLY in the Development CloudKit environment. TestFlight
# / App Store builds run against Production, which never auto-creates them, so
# the sync mirror fails with "Did not find any record types" and cross-device
# sync silently does nothing. Promoting the schema to Production is what fixes
# it - the same thing the CloudKit Console "Deploy Schema Changes..." button
# does, here scripted with Apple's `cktool`.
#
# HARD PREREQUISITE this script cannot do for you: the Development schema must
# already be populated. cktool promotes whatever is in Development; if Dev is
# empty there is nothing to deploy and the export will be empty. Seed Dev ONCE:
#   1. Run a DEBUG build on a device/simulator signed into iCloud.
#   2. Settings -> turn iCloud Sync ON.
#   3. Relaunch the app, then save a recipe.
# That auto-creates the CD_* record types in the Development environment. Then
# run this script. Full owner guide: Marketing/CICD.md ->
# "Deploying the CloudKit schema to Production".
#
# AUTH. You need a CloudKit *management* token (create it in CloudKit Console ->
# your container -> Settings -> API Access / Tokens; it is long-lived, ~1 year).
# Provide it either way:
#   * export CLOUDKIT_MANAGEMENT_TOKEN=...   (cktool auto-reads this), or
#   * run `xcrun cktool save-token --type management` once and follow the prompt
#     (stores it in your login keychain; then you can run this with no env var).
# The token is NEVER echoed and NEVER written to a tracked file.
#
# TEAM ID. Taken from $APPLE_TEAM_ID if set, else from DEVELOPMENT_TEAM in the
# gitignored App/DODApp.local.xcconfig (the same place your device builds read
# it). The team id is never committed.

set -euo pipefail

# The CloudKit container id is NOT secret - it ships in App/DODApp.entitlements.
CK_CONTAINER_ID="iCloud.com.dutchovendaddy.DODApp"

# Resolve repo root (this script lives in bin/).
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Resolve the Apple Team ID ------------------------------------------------
TEAM_ID="${APPLE_TEAM_ID:-}"
if [ -z "$TEAM_ID" ]; then
  LOCAL_XCCONFIG="$REPO_ROOT/App/DODApp.local.xcconfig"
  if [ -f "$LOCAL_XCCONFIG" ]; then
    # Pull `DEVELOPMENT_TEAM = XXXXXXXXXX` from the gitignored local override.
    TEAM_ID="$(sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*//p' "$LOCAL_XCCONFIG" | tr -d '[:space:]')"
  fi
fi
if [ -z "$TEAM_ID" ]; then
  echo "error: Apple Team ID not found." >&2
  echo "  Set it for this run:   export APPLE_TEAM_ID=XXXXXXXXXX" >&2
  echo "  ...or create the local override your device builds already use:" >&2
  echo "      echo 'DEVELOPMENT_TEAM = XXXXXXXXXX' > App/DODApp.local.xcconfig" >&2
  exit 1
fi

# --- Sanity-check the token is reachable (env or saved) -----------------------
# cktool reads the token from --token, then $CLOUDKIT_MANAGEMENT_TOKEN, then
# ~/.config/cktool, then the keychain. We don't pass --token (keeps it off the
# command line); if neither the env var nor a saved token exists, fail early
# with a clear message instead of a cryptic cktool error.
if [ -z "${CLOUDKIT_MANAGEMENT_TOKEN:-}" ] && [ ! -f "$HOME/.config/cktool" ]; then
  # The keychain may still hold a token from `cktool save-token`; we can't cheaply
  # detect that here, so this is a soft warning, not a hard stop.
  echo "note: CLOUDKIT_MANAGEMENT_TOKEN is not set and ~/.config/cktool is absent." >&2
  echo "      If you have not run 'xcrun cktool save-token --type management', this will fail to authenticate." >&2
fi

echo "Container : $CK_CONTAINER_ID"
echo "Team      : $TEAM_ID"
echo

SCHEMA_FILE="$(mktemp -t dod-ck-schema.XXXXXX).ckdb"
# Clean up the exported schema on exit (it can contain your record-type layout;
# no reason to leave it lying around).
trap 'rm -f "$SCHEMA_FILE"' EXIT

echo "==> Exporting Development schema ..."
xcrun cktool export-schema \
  --team-id "$TEAM_ID" \
  --container-id "$CK_CONTAINER_ID" \
  --environment development \
  --output-file "$SCHEMA_FILE"

if [ ! -s "$SCHEMA_FILE" ]; then
  echo "error: the exported Development schema is empty." >&2
  echo "       Nothing to promote. Seed the Development schema first (see the header" >&2
  echo "       of this script / Marketing/CICD.md), then re-run." >&2
  exit 1
fi
echo "    exported $(wc -l < "$SCHEMA_FILE" | tr -d '[:space:]') lines."

echo "==> Importing (promoting) schema into Production ..."
# --validate checks the schema against the Production container before applying.
# Importing to the production environment is the programmatic equivalent of the
# CloudKit Console "Deploy Schema Changes..." promotion.
xcrun cktool import-schema \
  --team-id "$TEAM_ID" \
  --container-id "$CK_CONTAINER_ID" \
  --environment production \
  --validate \
  --file "$SCHEMA_FILE"

echo
echo "Done. CloudKit Production schema now matches Development."
echo "Re-test cross-device sync on a TestFlight / Release build."
