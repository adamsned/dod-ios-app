# TestFlight Setup — v1.0

**Status:** T-184 — code is ready; **App Store Connect setup is manual**.

## Pre-flight checks (do these before archiving)

- [ ] `xcodebuild` Debug builds cleanly on iPhone 17 simulator (validated by CI).
- [ ] All package tests pass (validated by CI).
- [ ] App icon installed at `App/Assets.xcassets/AppIcon.appiconset/` (T-180).
- [ ] Screenshots captured per `Screenshots/README.md` (T-181).
- [ ] App Privacy questionnaire answered per `AppPrivacy.md` (T-182).
- [ ] Marketing copy reviewed in `AppStoreCopy.md` (T-183).
- [ ] Privacy policy URL is live at `https://www.dutchovendaddy.com/app-privacy/`.
- [ ] Support URL is live at `https://www.dutchovendaddy.com/app-support/`.
- [ ] Accessibility audit completed in simulator per `accessibility-audit.md`.
- [ ] Cold-launch trace shows < 1.5s per `performance-audit.md`.

## Apple Developer Program

Required:

- Apple Developer Program membership ($99/year).
- A Team ID — find at https://developer.apple.com/account → Membership.
- An App ID for `com.dutchovendaddy.DODApp` registered at
  https://developer.apple.com/account/resources/identifiers/list
- An App ID for `com.dutchovendaddy.DODApp.Widget` (the home-screen
  widget extension, US-9). Register it the same way — it lives alongside
  the host app's App ID.
- An App Group `group.com.dutchovendaddy.DODApp` registered at
  https://developer.apple.com/account/resources/identifiers/list?filter=applicationGroup
  and added to **both** the host App ID and the widget App ID under their
  Capabilities → App Groups settings. Without this the widget reads an
  empty UserDefaults suite and surfaces the placeholder forever (AC-9.4
  graceful-degrade path). Both `App/DODApp.entitlements` and
  `Widget/DODAppWidget.entitlements` already declare the group; only the
  developer-portal side is manual.

`project.yml` already sets `bundleIdPrefix: com.dutchovendaddy`,
`PRODUCT_BUNDLE_IDENTIFIER: com.dutchovendaddy.DODApp` (host) and
`com.dutchovendaddy.DODApp.Widget` (widget extension). Adjust if a
different identifier is preferred — and remember to mirror the change in
the two `.entitlements` files plus the developer-portal records.

## Widget extension — deferred scope

For v1.0 the `DODAppWidget` extension ships only `systemSmall` and
`systemMedium` families (spec.md US-9 AC-9.1). These v2 candidates are
intentionally out of scope:

- `systemLarge` home-screen size — would showcase 3-4 recipes at once;
  needs a list view treatment we haven't designed.
- Lock Screen `accessoryRectangular` / `accessoryCircular` /
  `accessoryInline` — requires a separate tinted asset pass, plus a
  decision on whether the lock screen variant deep-links into the app
  the same way (today's `widgetURL` triggers an unlock prompt).
- `accessoryCorner` (watchOS) — out for v1.0 per constitution §2.
- StandBy mode treatments — defer until we have telemetry on adoption.

Adding any of these is a 1-2 day task each: extend
`FeaturedRecipeWidget.supportedFamilies`, add a new entry view variant,
land matching snapshot baselines. No new App Group plumbing required.

## App Store Connect

1. Sign in at https://appstoreconnect.apple.com.
2. **My Apps → +** → New App.
   - Platform: iOS
   - Name: Dutch Oven Daddy
   - Primary language: English (U.S.)
   - Bundle ID: `com.dutchovendaddy.DODApp` (must match the registered App ID)
   - SKU: any unique string (e.g. `dod-ios-001`)
   - User Access: Full Access
3. In the new app's **App Information** tab — fill out per `AppStoreCopy.md`.
4. In **App Privacy** — answer per `AppPrivacy.md`.
5. In **Pricing and Availability** — free, all territories (or restrict as desired).

## TelemetryDeck app ID

1. Sign up at https://telemetrydeck.com (free tier is fine for v1).
2. Create a new app called "Dutch Oven Daddy iOS."
3. Copy the App ID.
4. Create a gitignored `App/DODApp.xcconfig`:

   ```
   TelemetryDeckAppID = <your-app-id-here>
   ```

5. Reference it from `App/Info.plist`:

   ```xml
   <key>TelemetryDeckAppID</key>
   <string>$(TelemetryDeckAppID)</string>
   ```

6. Reference the xcconfig in `project.yml` under `settings:` →
   `configFiles: { Debug: App/DODApp.xcconfig, Release: App/DODApp.xcconfig }`.
7. Regenerate the project: `xcodegen generate`.

If you skip this, the app launches fine — telemetry just no-ops.

## Archive + upload

```bash
cd ~/Developer/DODApp
xcodegen generate
xcodebuild archive \
    -project DODApp.xcodeproj \
    -scheme DODApp \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath build/DODApp.xcarchive
xcodebuild -exportArchive \
    -archivePath build/DODApp.xcarchive \
    -exportOptionsPlist build/ExportOptions.plist \
    -exportPath build/Export
```

You'll need an `ExportOptions.plist` — generate it once via Xcode's
**Distribute App** wizard, then reuse.

Easier: open the project in Xcode, **Product → Archive**, then in the
Organizer click **Distribute App → App Store Connect → Upload**.

## TestFlight — internal beta

1. After upload, the build appears under **TestFlight** in App Store
   Connect within ~10 minutes.
2. Add **Internal Testers** (yourself + family/friends, up to 100 total).
3. They get the TestFlight invite immediately; no Apple review needed.
4. Bake for 2 weeks per `plan.md` rollout step 2.

## TestFlight — external beta (skip for v1 unless needed)

External testing requires Apple beta review (1-2 days). Only worth it
if you need broader feedback before App Store submission.

## App Store submission

After the TestFlight bake:

1. Pick the TestFlight build for the v1.0 release.
2. Fill in all "Prepare for Submission" fields (already drafted in the
   marketing docs).
3. Submit for review.
4. Apple's first-time-app review SLA is typically 24-48 hours but can be
   longer. Plan accordingly.

## If rejected

Most-common reasons for first-time iOS apps:

- **Missing privacy policy link** — confirm the URL loads in a browser.
- **App icon shape** — must be a square PNG, no transparency, no rounded
  corners (Apple rounds them).
- **Crash on launch on the reviewer's device** — usually a missing
  Info.plist key or unimplemented permission usage. Our v1 needs no
  permissions, so this should be unlikely.
- **Metadata mismatch** — App Privacy answers must match what the binary
  actually does. Our binary only talks to TelemetryDeck and dutchovendaddy.com
  — if a future version adds another endpoint, update App Privacy first.

Iterate; re-submit.
