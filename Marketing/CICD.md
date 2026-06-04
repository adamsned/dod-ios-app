# Continuous Deployment to TestFlight

This document explains the automated release pipeline that archives a Release
build of Dutch Oven Daddy and uploads it to TestFlight, what GitHub secrets it
needs, and the exact steps the maintainer must complete to turn it on.

The pipeline is the workflow at `.github/workflows/release.yml`. It runs on top
of the existing CI (`.github/workflows/ci.yml`) and does not modify or replace
it. CI keeps gating every pull request (build + tests on the simulator); this
release workflow only archives and uploads when you explicitly ask for a
release.

Status: the workflow, the export options, and these docs are committed, but the
pipeline cannot authenticate to Apple until the maintainer adds the secrets
listed below. Until then, a run will fail at the signing/upload step. The
project-generation steps (xcodegen, package resolve) run fine without secrets.


## What the pipeline does, end to end

1. Triggered manually (Actions tab -> Release (TestFlight) -> Run workflow) or
   by pushing a tag that matches `release-*` (for example `release-2026.05.31`).
2. Runs on a `macos-15` runner and selects the newest installed Xcode 26 (same
   selection logic as CI).
3. Installs XcodeGen and runs `xcodegen generate` to produce `DODApp.xcodeproj`
   (the project file is gitignored and always generated).
4. Computes a build number and stamps it into the three Info.plists (app,
   Widget, LiveActivity). See "Build-number scheme" below.
5. Decodes the App Store Connect API key (`.p8`) from a base64 secret to a file
   on the runner.
6. Archives the app in Release with automatic ("managed") cloud signing for
   distribution, using `-allowProvisioningUpdates` plus the API key so Xcode
   creates/refreshes the App Store distribution certificate and provisioning
   profiles for the app and both extensions (Widget + LiveActivity), including
   their iCloud/CloudKit, App Groups, and remote-notification entitlements.
7. Exports the archive to an `.ipa` using the committed `exportOptions.plist`
   (method app-store-connect, automatic signing). The Apple Team ID is injected
   into a runtime copy of that plist; it is never committed.
8. Uploads the `.ipa` artifact to the workflow run (kept 14 days as a fallback
   you can hand-upload via Transporter), then uploads it to TestFlight with
   `xcrun altool --upload-app`.

After the upload, App Store Connect processes the build (usually a few minutes)
and emails you. You still assign the build to a TestFlight test group in App
Store Connect, and fill in "What to Test" (see `Marketing/TestFlight.md`).


## Build-number scheme

App Store Connect rejects a build number (CFBundleVersion) that has already been
accepted for the current marketing version. A build number can never be re-used.

The maintainer currently bumps CFBundleVersion by hand in `project.yml` (it
lives in three places kept in lockstep: the App, the Widget, and the
LiveActivity) as a small integer such as "4". That manual scheme is fine for
local and manual Xcode builds.

To avoid colliding with the manual bumps and to stay strictly monotonic without
anyone bumping a number, the CD pipeline overrides CFBundleVersion at archive
time with a UTC timestamp in dotted form:

    YYYY.MMDD.HHMM        for example 2026.0531.1830

Why this exact shape:

- It strictly increases with wall-clock UTC time, so it is never re-used.
- Each dotted component stays under 2^32 minus 1, which Apple requires for every
  component of a CFBundleVersion. A single 12-digit value like 202605311830
  would exceed 2^32 and be rejected, which is why the value is dotted.
- It always sorts above the maintainer's small hand-bumped integers (4, 5, ...),
  so the manual lane and the CD lane never collide regardless of order.
- It is independent of the marketing version (1.0); only the build number moves.
  The marketing version is still controlled by MARKETING_VERSION in
  `project.yml`.

The workflow writes this value into all three Info.plists with PlistBuddy so the
app and both extensions stay in lockstep (Apple rejects version skew between an
app and its app-extension bundles).

Alternative, documented but not used: GitHub's `${{ github.run_number }}`. It is
monotonic per workflow but starts at 1, so a brand-new release workflow would
emit build "1" and collide with the existing manual "4". You could switch to it
by editing the "Compute build number" step, but only after the run number has
been seeded above the current manual baseline. The timestamp scheme avoids that
foot-gun, which is why it is the default.


## GitHub secrets and variables to add

Add these as repository secrets (Settings -> Secrets and variables -> Actions ->
New repository secret). The repository is PUBLIC, so none of these may ever be
committed to a tracked file; secrets are the correct home for all of them.

Required secrets:

- ASC_KEY_ID
  The App Store Connect API key's Key ID. About 10 characters, for example
  ABCDE12345. Shown in App Store Connect next to the key after you generate it.

- ASC_ISSUER_ID
  The Issuer ID for your App Store Connect API keys. A UUID, for example
  69a6de7e-aaaa-bbbb-cccc-1a2b3c4d5e6f. Shown at the top of the App Store
  Connect API page (it is the same for all keys in your account).

- ASC_KEY_P8_BASE64
  The base64 encoding of the downloaded private key file AuthKey_<KEY_ID>.p8.
  Apple lets you download the .p8 only once, so store it somewhere safe too.
  Generate the base64 on a Mac with:
      base64 -i AuthKey_ABCDE12345.p8 | pbcopy
  then paste it as the secret value. (On Linux: base64 -w0 AuthKey_...p8.)

- APPLE_TEAM_ID
  The Apple Developer Team ID (the 10-character string, the OU field of your
  signing certificate). This is intentionally NOT stored in any tracked file in
  this public repo. The workflow injects it into signing and into a runtime copy
  of exportOptions.plist.

Optional but recommended (stops the per-build certificate pile-up - see
"Certificate reuse" below):

- SIGNING_CERT_P12_BASE64
  Base64 of a `.p12` export of your DOD signing certificate (with its private
  key). When set, the release runner imports this certificate and reuses it
  instead of letting automatic signing mint a brand-new certificate on every
  run. Without it, each release creates a new "Created via API" certificate that
  accumulates toward Apple's per-account cap, eventually forcing a manual
  revocation before a release can sign. Absent = the old behavior (the workflow
  warns and continues).

- SIGNING_CERT_P12_PASSWORD
  The password you set when exporting the `.p12`.

This pipeline does not require any repository variables; everything sensitive is
a secret. If you prefer, APPLE_TEAM_ID could be a repository variable instead of
a secret (it is not strictly a credential), but keeping it a secret is simplest
and matches the constitution rule of not exposing the team id.


## How to generate the App Store Connect API key

You need an account with permission to create keys (Account Holder or Admin).

1. Go to https://appstoreconnect.apple.com and sign in.
2. Open Users and Access.
3. Open the Integrations tab, then App Store Connect API (older UI labels this
   "Keys" under "Keys").
4. If this is the first key, you may be asked to request access; approve it.
5. Click the add (plus) button to generate a new key.
6. Give it a name (for example "DOD CI Upload"). For Access, choose the
   App Manager role. App Manager is sufficient to upload builds to TestFlight;
   do not grant Admin unless you have a separate reason.
7. Generate the key. Copy the Key ID (this is ASC_KEY_ID) and note the Issuer ID
   shown at the top of the page (this is ASC_ISSUER_ID).
8. Download the API key (the AuthKey_<KEY_ID>.p8 file). You can only download it
   once. Store it in a password manager or other secure vault.
9. Base64-encode the .p8 and add it as ASC_KEY_P8_BASE64 (see the secrets list
   above for the exact command).


## Certificate reuse (stop the per-build certificate pile-up)

By default the workflow uses automatic ("managed") cloud signing. On a fresh CI
runner the keychain is empty, so `-allowProvisioningUpdates` mints a NEW Apple
signing certificate via the API key on every release. Apple caps the number of
certificates per account, so after a handful of releases the cap is hit and the
archive fails with "Your account has reached the maximum number of certificates.
To create a new one, you must choose a certificate to revoke." - which forces a
manual cert revocation before you can ship again.

The fix is to provide ONE fixed certificate that the runner imports and reuses,
so no new certificate is ever created. It is purely additive: the workflow's
"Reuse a fixed signing certificate" step is a no-op (it warns and continues)
until the secret is set, so nothing breaks before you do this.

One-time setup:

1. On your Mac, open Keychain Access (login keychain).
2. Find your DOD signing certificate(s) that have a private key under them (the
   row expands with a disclosure triangle to show a "private key" child). At
   minimum this is your "Apple Development" certificate - the one that has been
   piling up as "Created via API". If your "Apple Distribution" certificate also
   shows a private key, select it too (both can go in one .p12).
3. Select the certificate(s), right-click -> Export ... -> Personal Information
   Exchange (.p12), save it (e.g. dod-signing.p12), and set an export password.
   Remember that password.
4. Base64-encode it:
       base64 -i dod-signing.p12 | pbcopy
5. Add two repository secrets (Settings -> Secrets and variables -> Actions):
   - SIGNING_CERT_P12_BASE64    = the base64 from step 4
   - SIGNING_CERT_P12_PASSWORD  = the export password from step 3
6. Dry run (Actions -> Release (TestFlight) -> Run workflow, skip_upload = true).
   In the "Reuse a fixed signing certificate" step log you should see your
   identity under "Signing identities now available to xcodebuild", and the
   archive should succeed WITHOUT a new "Created via API" certificate appearing
   in the Developer portal.

Notes:

- The certificate must be valid (not expired or revoked) and belong to your
  team. Update the secret if you ever rotate the certificate.
- This stores a private key as a GitHub secret. That is standard for iOS CI
  signing; keep the .p12 + password in your password manager as the source of
  truth. The repo is public, so the cert + password must only ever live as
  secrets, never in a tracked file.
- Once this is working you can safely revoke the leftover "Created via API"
  development certificates in the portal to reclaim the cap.


## How to trigger a release

Two ways, both already wired up:

Manual:
1. Go to the repository's Actions tab.
2. Select the "Release (TestFlight)" workflow.
3. Click "Run workflow", choose the branch (normally main), and run.
4. Optional: set "skip_upload" to true to archive and export the .ipa without
   uploading. This is a safe dry run; the .ipa is attached to the run as an
   artifact you can inspect or hand-upload via Transporter.

By tag (recommended for a real release, leaves an audit trail):
    git tag release-2026.05.31
    git push origin release-2026.05.31
Any tag matching `release-*` triggers the workflow. The build number is still
the UTC timestamp computed at run time, independent of the tag text.

Note: the pipeline does NOT auto-deploy on every push to main, by design. If you
ever want that, replace the `push: tags:` trigger block in
`.github/workflows/release.yml` with:
    push:
      branches: [main]
and remove the tag filter. Be aware this uploads a TestFlight build on every
merge to main, which burns runner minutes and App Store Connect processing on
every change; the tag-based trigger is the safer default.


## What you must do to finish enabling this

This is the checklist to take the pipeline from "committed but inert" to "works".

1. Apple Developer Program: confirm the app's bundle id
   com.dutchovendaddy.DODApp is registered and the App Store record exists in
   App Store Connect (it does if you have shipped TestFlight before). If this is
   the first ever upload, create the app in App Store Connect first.

2. Confirm the App ID capabilities and CloudKit container are provisioned for
   distribution: iCloud (with CloudKit support), the App Group
   group.com.dutchovendaddy.DODApp, and the push/remote-notification capability.
   See Marketing/TestFlight.md for the detailed click-through. Automatic signing
   will mint the App Store provisioning profiles, but the capabilities must be
   enabled on the App ID first.

3. Generate the App Store Connect API key with the App Manager role and download
   the .p8 once (see "How to generate the App Store Connect API key" above).

4. Add the four repository secrets (see "GitHub secrets and variables to add"):
   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64, APPLE_TEAM_ID.

4b. Recommended: add SIGNING_CERT_P12_BASE64 + SIGNING_CERT_P12_PASSWORD so the
   runner reuses one fixed certificate instead of minting a new one every
   release (see "Certificate reuse (stop the per-build certificate pile-up)"
   above). Without this you will periodically hit Apple's certificate cap and
   have to revoke an old cert before a release can sign.

5. Do a dry run: Actions -> Release (TestFlight) -> Run workflow with
   skip_upload = true. Confirm it archives and exports an .ipa and attaches it
   as an artifact. This proves signing works without risking a bad upload.

6. Do a real run: either Run workflow with skip_upload = false, or push a
   `release-*` tag. Watch the "Upload to TestFlight (altool)" step succeed.

7. In App Store Connect, wait for the build to finish processing, then assign it
   to your TestFlight test group and fill in "What to Test"
   (see Marketing/TestFlight.md).

Notes and gotchas:

- The first archive on a fresh signing setup can take longer while Xcode creates
  the distribution certificate and profiles; later runs are faster.
- If the upload is rejected for a re-used build number, it means a build with
  that CFBundleVersion already exists for marketing version 1.0; because the
  scheme is a UTC timestamp this should not happen unless two runs start in the
  same minute (the concurrency group serializes runs to prevent that).
- altool is the scriptable uploader and remains current in Xcode 26
  (altool 26.40.x). notarytool is for notarizing macOS apps, not for
  App Store / TestFlight delivery, so it is intentionally not used here.
- No third-party tooling (no fastlane, no Ruby/Gemfile) is added; the pipeline
  is pure xcodebuild + xcrun + the App Store Connect API key, per the
  constitution default of no new third-party dependencies.


# Auto-filing test-failure bugs in Linear

When the CI test suite goes red on `main`, CI files one rollup bug issue in
Linear automatically. This is separate from the TestFlight pipeline above and
from the nightly live-API job (`.github/workflows/nightly-live-api.yml`, which
opens a GitHub issue, not a Linear one). This section explains the mechanism and
the one-time owner setup.


## What it does, end to end

1. The `report-failures` job in `.github/workflows/ci.yml` runs at the end of
   every CI run, but only when `failure() && github.ref == 'refs/heads/main'` is
   true. That means it is a strict no-op on green runs and on every pull request
   (PR runs have a `refs/pull/<n>/merge` ref, never `refs/heads/main`), so PR
   branches never file issues.
2. It collects which needed jobs failed by reading the `needs.*.result` contexts
   (serialized with `toJSON(needs)` and filtered with `jq` to the job ids whose
   result is exactly `failure`).
3. It invokes `bin/file_test_bugs.py` with the commit SHA, a link to the GitHub
   Actions run, and the comma-separated list of failed job ids, passing the
   Linear key as the `LINEAR_API_KEY` environment variable from
   `secrets.LINEAR_API_KEY`.
4. The script talks to the Linear GraphQL API (https://api.linear.app/graphql)
   using only the Python standard library (no pip, no SwiftPM dependency). It
   resolves the "Dutch Oven Daddy" team, the `bug` and `test-failure` labels
   (creating either if missing), and the team's unstarted "Todo" workflow state.
5. Dedup is idempotent by commit SHA. The script searches the team's open
   `test-failure`-labeled issues for a hidden marker
   `<!-- dod-bugfiler:sha=<full-sha> -->` in the description:
   - If found, it adds a comment ("Still red on re-run: <run-url>") to that
     existing issue instead of opening a duplicate.
   - If not found, it creates one new rollup issue.
   So re-running CI on the same red commit updates the same issue; a new red
   commit opens a new rollup issue.
6. The reporter job never fails the build. The required gate is the existing
   `ci-required` job; `report-failures` only reports, and any filer error is
   downgraded to a warning.


## The rollup issue

- Title: `Test suite red on main @ <short-sha>`.
- Description: the list of failed jobs annotated with their CI layer, the full
  commit SHA, a link to the GitHub run, and the hidden dedup marker.
- Labels: `bug` and `test-failure`.
- State: the team's unstarted "Todo" workflow state.
- Priority: the maximum severity among the failed layers, by this map:

      L2 build      / L0 tooling   -> Urgent (1)
      L1 unit       / L3 UI smoke  -> High   (2)
      L4 snapshot                  -> Medium (3)
      L5 live-API / E2E            -> Low    (4)

  Each failed GitHub job is mapped to a layer by its job id / display name (for
  example `build-app` -> L2, `test-ui-smoke` -> L3, `test-snapshots-designsystem`
  -> L4, `test-e2e` -> L5, `lint` / `format` / `changes` -> L0). A job that
  cannot be mapped defaults to High, so it is never silently dropped.


## Running it locally / dry run

The script supports `--dry-run`, which prints the exact GraphQL operations it
would send and makes no network calls (so it needs no key):

    python3 bin/file_test_bugs.py \
      --sha 0123456789abcdef0123456789abcdef01234567 \
      --run-url "https://github.com/adamsned/dod-ios-app/actions/runs/123" \
      --failed-jobs "build-app,test-ui-smoke,test-snapshots-designsystem" \
      --dry-run

Unit tests (standard library `unittest`, no key required) cover the priority
mapping, marker build/parse, the dedup decision, and payload construction:

    python3 -m unittest discover -s bin -p 'test_*.py'


## Owner setup (one time)

The mechanism is committed and inert until you add one repository secret. Until
then, a red run on `main` logs a warning ("LINEAR_API_KEY secret is not set;
skipping Linear bug filing") and files nothing; it never breaks the build.

1. Create a Linear Personal API key: in Linear, open Settings -> Account ->
   Security & Access -> Personal API keys -> "New key" (some Linear builds label
   this menu "Security & access"). Give it a name such as "DOD CI bug filer".
   A key restricted to Create issues and Create comments on the Dutch Oven Daddy
   team is sufficient; full access also works. Copy the key value (shown once).
2. Add it as a GitHub Actions repository secret. In GitHub, open the repository
   Settings -> Secrets and variables -> Actions -> New repository secret. Name it
   exactly `LINEAR_API_KEY` and paste the key as the value. The repository is
   public, so the key must only ever live as this secret, never in a tracked
   file.
3. That is all. The first real issue is filed the next time `main` goes red
   after the secret is added. Nothing is back-filled for past failures.

Notes:

- Linear personal API keys are sent as the raw key in the `Authorization` header
  with no `Bearer` prefix (verified against developers.linear.app). The script
  does this and never logs the key.
- The team id (`6ca2f53d-4a1b-4f1d-b7a5-b26564d09705`) is not a credential and is
  hardcoded in the script; only the API key is secret.
- The reporter runs on `ubuntu-latest` (not a macOS runner) because the filer is
  pure Python standard library and does no Xcode work, which keeps it fast and
  cheap.
