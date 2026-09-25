# Constitution — Dutch Oven Daddy iOS App

Immutable rules. All specs, plans, and tasks must conform. Changes require an explicit constitution amendment, not silent drift.

## 1. Product identity

- Native iOS/iPadOS app for the Dutch Oven Daddy cooking blog (dutchovendaddy.com).
- Primary job: let readers browse, search, save, and cook recipes from the blog on iPhone and iPad.
- Brand: warm, food-forward, readable. Recipes are the hero — chrome is minimal.
- The app is **mostly** read-only: every recipe is a tap away without sign-in. v1.0 adds **two write surfaces** — submitting a rating (1–5 stars) and posting a comment on a recipe — both of which post directly to the dutchovendaddy.com WordPress install via its REST API. No accounts; see §9 for the guest-identity model.

### 1.1 v1.x sync model (added 2026-05-28 by the US-41 / T-700 amendment per CL-86 / CL-87)

- **No accounts in our system; the user's iCloud account is the sync identity.** v1.x adds optional cross-device sync of saved recipes via CloudKit private database (per US-41). There is no Account icon, no login sheet, no OAuth providers, no password handling, and no login UI in our app. The user's iCloud account *is* the sync identity — accessed via `CKContainer.accountStatus(completionHandler:)` (the system-level affordance, no UI surface of ours). The only configuration surface is a Settings → iCloud Sync toggle (US-41 / AC-41.3).
- **The "mostly read-only with two write surfaces" framing is preserved.** The CloudKit mirror is a sync mechanism, not a new write surface. The user-facing write surfaces remain Save / Comment / Rate per the existing US-13 / US-14 / US-15. CloudKit reads/writes the *user's own data* (their saved recipes), not the blog's read surface.
- **Guest identity (US-15) remains unchanged.** Name + email for comments + ratings stay Keychain-stored, per-device, sent only to dutchovendaddy.com over HTTPS, no TelemetryDeck. CloudKit sync does NOT replace or change that — guest identity is for *posting to the blog*, which is unrelated to syncing the user's own saved recipes across their own devices. The two systems don't touch each other (CL-88 explicitly excludes the Keychain guest identity from the sync scope).
- **App Store compliance.** The CloudKit-private-DB-only posture satisfies Apple App Store Review Guideline 5.1.1(ii) ("If your app doesn't include significant account-based features, let people use it without a login" — locked by AC-41.1 + REG-26) and 5.1.1(v) ("apps that offer account creation must offer account deletion" — non-applicable per CL-92 because there is no account in our system; the AC-41.5 toggle-off + iCloud sign-out paths fully remove the app's data from the user's iCloud space).

## 2. Platforms & versions

- **Targets:** iPhone and iPad. Universal app, single binary.
- **Minimum OS:** iOS 17 / iPadOS 17.
- **Orientation:** portrait + landscape on iPad; portrait-primary on iPhone (landscape allowed for recipe reading and video).
- **No** watchOS, macOS Catalyst, or visionOS in v1. Revisit after launch.
- **Cook Mode** is in scope for v1.0 (a hands-free, screen-awake cooking surface on recipe detail). Was previously an implicit non-feature; promoted in by the consultant-pass amendment (CL-16, spec US-7). Watch / Mac / Vision targets remain out.
- **Widget extension included** for v1.0 — a WidgetKit extension (`app-extension` target, NSExtensionPointIdentifier `com.apple.widgetkit-extension`, bundle ID `com.dutchovendaddy.DODApp.Widget`) embedded in the host app bundle, surfacing today's featured recipe on the home screen in `systemSmall` and `systemMedium`. Promoted in by the consultant-pass amendment (2026-05-23, spec US-9). Data flows from app to widget via the shared App Group `group.com.dutchovendaddy.DODApp`; no new analytics, no new network endpoints, no PII. Large + Lock Screen accessory families remain out for v1. Watch / Mac / Vision targets still out.
- **ActivityKit (iOS 16.1+)** is used for Cook Mode timers (spec US-11). When a user starts a step timer in Cook Mode, the app pushes a Live Activity so the countdown surfaces on the Lock Screen and (on iPhone 14 Pro and later) in the Dynamic Island. ActivityKit calls are wrapped behind `if #available(iOS 16.1, *)` and guarded with `#if os(iOS)` so the package still builds on the macOS test slice. Pre-iOS 16.1 hosts and users who have disabled Live Activities system-wide degrade silently to the inline timer only (spec AC-11.4). The Live Activity payload (`recipeTitle`, `recipeID`, `remainingSeconds`, `stepText`, `isPaused`) carries no PII and is not telemetry — it is a system-presented countdown, not an event sent to TelemetryDeck, and the App Privacy questionnaire is unaffected (parallel to the idle-timer note in §9).
- **FoundationModels / Apple Intelligence (iOS 26+)** powers the optional on-device AI affordances (spec US-54): recipe + article summary, shopping-list ingredient substitution, and the Cooking Tools helper. Every FoundationModels call site is wrapped behind `@available(iOS 26, *)` and guarded with `#if os(iOS)` (so the packages still build on the macOS test slice), and gated at runtime by a `SystemLanguageModel` availability probe (`SystemLanguageModel.default.availability`). On iOS 17–25 hosts, on Apple-Intelligence-incapable hardware, or when the model reports unavailable (not enabled / still downloading / device not eligible), the AI affordances **simply don't appear** — the app degrades silently to its existing non-AI surfaces, exactly the same silent-degrade philosophy already documented above for ActivityKit (iOS 16.1) and the iOS-18 Control widget. The model runs entirely on-device: no network round-trip, no data sent anywhere, no new analytics (see §4.1 + §9). The framework dependency is recorded in §3; the scope + task split live in spec US-54 / CL-331. Added 2026-07-17 by the US-54 / T-930 amendment per CL-328.

## 3. Tech stack

- **Language:** Swift 5.9+. No Objective-C unless bridging a required dependency.
- **UI:** SwiftUI first. Drop to UIKit only with a documented reason in the relevant `plan.md`.
- **Concurrency:** Swift Concurrency (`async/await`, actors). No completion-handler APIs in new code; wrap legacy callbacks at the boundary.
- **State:** `@Observable` (Observation framework) for view models. `@State`/`@Binding` for local view state. No third-party state libraries.
- **Persistence:** SwiftData for local cache and saved recipes. Plain `Codable` + file storage acceptable for simple key-value needs.
- **Networking:** `URLSession` + `Codable`. No Alamofire/Moya.
- **Images:** Native `AsyncImage` with a thin disk-cache wrapper; no SDWebImage/Kingfisher unless a documented gap forces it.
- **Dependencies:** Swift Package Manager only. New dependencies require justification in the plan and approval at the Phase 3 checkpoint. Default answer is "no new dependency." Currently approved:
  - `TelemetryDeck/SwiftSDK` — analytics transport (§9).
  - `pointfreeco/swift-snapshot-testing` — visual regression (§6, L4). Test target only; never imported by production code.
  - `CloudKit.framework` — Apple-provided system framework added 2026-05-28 by the US-41 / T-700 amendment per CL-86 / CL-87 / CL-93. **Not a third-party dependency** — ships with iOS, no SPM footprint, no package-manager entry, no annual license. Used by `DODPersistence` for the optional cross-device sync of saved recipes via the user's CloudKit private database (`iCloud.com.dutchovendaddy.DODApp`); accessed through SwiftData's iOS 17+ `ModelConfiguration(_:groupContainer:cloudKitDatabase: .private(...))` adapter rather than directly. The two iCloud entitlement keys (`com.apple.developer.icloud-container-identifiers` + `com.apple.developer.icloud-services` per CL-93) are the only entitlement-cost. Reaffirms "default answer is no new third-party dep" — CloudKit was the deliberate iCloud-sync path because the alternative paths (WordPress users + WP OAuth plugin, Firebase, Supabase, local-only + manual iCloud sync) all required either a third-party SDK, a paired web-backend effort, or a worse UX; see CL-86 for the considered-alternatives trail.
  - `FoundationModels.framework` — Apple-provided system framework added 2026-07-17 by the US-54 / T-930 amendment per CL-327. **Not a third-party dependency** — ships with iOS, no SPM footprint, no package-manager entry, no annual license. It is the on-device Apple Intelligence large language model (Apple's ~3B-parameter system model), used **only on-device** for the optional AI affordances in US-54 (recipe/article summary, shopping-list ingredient substitution, the Cooking Tools helper) behind the shared `DODIntelligence` service (T-931). Accessed through `SystemLanguageModel` + `LanguageModelSession`, never a network client. **Even lighter than CloudKit** (the CL-86 precedent this bullet is templated on): where CloudKit added two iCloud entitlement keys + an App Store Connect container + a `fastlane match` re-provision step (CL-93), FoundationModels adds **zero entitlements, no iCloud container, no provisioning, and no network egress** — it is a compute-only framework whose input and output never leave the device (see §4.1 + §9), so the privacy story is strictly cleaner than CloudKit's (CloudKit at least sends to the user's own iCloud container; FoundationModels sends nothing). **iOS 26+ only**, so every call site is `@available(iOS 26, *)` + `#if os(iOS)` gated with graceful degradation + a runtime `SystemLanguageModel` availability probe (see §2). Reaffirms "default answer is no new third-party dep" — the on-device path was the deliberate choice over the **cloud-LLM** alternative (Claude / GPT-4V with text/photo upload), which would add a third-party SDK, a per-request cost, and a **new** privacy-egress surface (a §9 conflict); the cloud-LLM path stays explicitly out of scope as a separate future §9 amendment (see CL-331 + the cast-iron-scanner backlog entry's architecture-decision tree, which named on-device Foundation Models the "best privacy" path).

## 4. Content source

- **Primary:** WordPress REST API at `https://dutchovendaddy.com/wp-json/wp/v2/`.
- **Recipe data:** WP Recipe Maker fields where available (`/wp-json/wp/v2/posts` + WPRM endpoints).
- **Offline:** All viewed recipes cached locally. Explicitly saved recipes are guaranteed available offline (images included).
- **No** scraping HTML as a primary source. HTML parsing only as a documented fallback for fields the API does not expose.
- **No** auth required for reads in v1. Anonymous client.

### 4.1 Data boundaries (added 2026-05-28 by the US-41 / T-700 amendment per CL-86 / CL-87 / CL-88)

This section enumerates the three data categories the app touches and the boundary each crosses. The categorization governs the App Privacy questionnaire (§9) and the per-feature scope decisions.

| Category | Where stored | What leaves the device | To where |
|---|---|---|---|
| **Cached data** (existing) | SwiftData local store on device + the App Group container for the widget bridge | None (reads only — the network direction is WP REST → device) | n/a (inbound only) |
| **Guest identity** (US-15, existing) | iOS Keychain on device only, service `com.dutchovendaddy.DODApp.guest` | Name + email (only when the user posts a comment or rating, per US-13 / US-14) | `dutchovendaddy.com` over HTTPS (the WP REST endpoints `/wp/v2/comments` + `/wp-recipe-maker/v1/rating`) |
| **Synced records** (US-41, new in v1.x) | SwiftData local store, mirrored via CloudKit's `cloudKitDatabase: .private(...)` adapter | The synced fields on `CachedRecipe` rows where `isSaved == true` (per AC-41.4's enumerated field list) + the relevant `CachedImage` rows | The user's own CloudKit private database under container `iCloud.com.dutchovendaddy.DODApp` (Apple-hosted, user-owned, user-controlled, encrypted in transit + at rest per Apple's CloudKit security model) |
| **Analytics events** (§9, existing + extended) | n/a (ephemeral) | Closed-enum event names + closed-enum payload values (no PII, no free text) | TelemetryDeck's anonymous endpoint |

- The "Synced records" category does NOT change the §4 "No auth required for reads in v1. Anonymous client." rule — CloudKit reads/writes the user's *own data*, not the blog's read surface. Anonymous-WP-REST-client posture is preserved.
- Apple's own App Privacy guidance for CloudKit-using-but-private-DB-only apps is at https://developer.apple.com/app-store/app-privacy-details/ — the relevant passage: "If your app uses CloudKit and only sends data to the user's own CloudKit container, you do not need to disclose the data as collected by your app." Per CL-94, the App Privacy questionnaire mapping table in §9 stays unchanged.
- The CloudKit container identifier `iCloud.com.dutchovendaddy.DODApp` matches the bundle ID prefix per CL-93. Only the **private** database is accessed; the public + shared databases are explicitly out of scope for v1.x (locked by REG-25); the Discoverability API is explicitly out of scope (locked by REG-25). See CL-88 for the full sync-scope enumeration and the deferral triggers.
- **On-device AI inference adds no new egress and no new data category (US-54, per CL-329).** The optional Apple Intelligence affordances (recipe/article summary, shopping-list ingredient substitution, the Cooking Tools helper) run the on-device FoundationModels LLM (§3) over text the app has **already cached** — recipe bodies, article bodies, and ingredient lines that are all the existing **"Cached data"** category (row 1 above). Inference is a **compute** operation, not a new data category: the model reads already-on-device text and produces **derived text (summaries, substitutions, answers) that ALSO never leaves the device** — no network request is made, nothing is sent anywhere, and the derived output is either shown to the user transiently or stays in the same on-device store as its input. So the enumeration above still holds — no fourth boundary is crossed, "Cached data" still has "None" leaving the device — and this is strictly cleaner than the "Synced records" row (which at least mirrors to the user's own iCloud): FoundationModels egress is **zero**. This parallels the §2 Live Activity payload note and the §9 local-notifications note ("nothing is sent"). The **cloud-LLM** path (uploading text or photos to a third-party model) *would* be a genuinely new egress boundary + a new row in this table + a §9 amendment; it is explicitly out of scope (CL-331).

## 5. Architecture

- **Pattern:** MV (Model + View) with `@Observable` view models. No VIPER, no Clean Architecture ceremony.
- **Layers:**
  1. `Networking/` — API client, request/response types.
  2. `Persistence/` — SwiftData models, cache policy.
  3. `Domain/` — recipe, category, search models (pure value types).
  4. `Features/<FeatureName>/` — view + view model + tests, one folder per feature.
  5. `DesignSystem/` — colors, typography, reusable components.
- **No** singletons except for genuinely process-wide services (e.g. `URLCache`). Use dependency injection via initializers.

## 6. Testing — required for every PR

The test pyramid has **five** layers. Every PR must keep L1–L4 green; L5 runs selectively (see below). The four-layer pyramid was the constitution shape from v1.0 launch through Phase 10; Phase 11 (2026-05-26) added L5 end-to-end coverage with selective gating — see [`dod-ios-app/test-pyramid-audit.md`](dod-ios-app/test-pyramid-audit.md) and `dod-ios-app/clarifications.md` CL-58 for the rationale.

### L1 — Unit tests (Swift Testing)
- Every view model, networking type, and domain transform.
- Use **Swift Testing** (`import Testing`), not XCTest, for new code.
- Run inside each package via `swift test`.

### L2 — Live-API integration tests
- Hit the real WordPress REST endpoint + parse a real recipe page.
- Catch contract drift the unit-test fixtures cannot (the `_embed` / `_fields` interaction that hid hero images in v1 is the canonical example).
- Tagged `live-api`; runs **nightly in CI**, opt-in locally. Skipped on every PR to avoid flake from blog availability.
- **Read-only**: L2 tests never POST to dutchovendaddy.com — they pin contract shape on GETs only. The blog's write surfaces (`/wp/v2/comments`, `/wp-recipe-maker/v1/rating`) are exercised at L1 against fakes; L5 will exercise them against stubs once T-610 / T-611 land.

### L3 — UI smoke tests (XCUITest)
- Launch the app, navigate the golden path (browse → detail → save → offline read), assert content actually renders.
- Catch crashes-on-launch and missing-content regressions (the TelemetryDeck pre-init crash and the empty-image bug from v1 are the canonical examples).
- Run on **every PR** in CI.
- Scheme: `DODAppUITests` (kept lean — fast reachability checks only; longer user-journey walks belong at L5, see T-612).

### L4 — Visual regression (snapshot tests)
- PNG snapshots on disk for every reusable DesignSystem component, top-level Feature view, and key state (loading / loaded / empty / error / offline), in light + dark, iPhone + iPad size classes.
- Failing snapshot = visible diff in CI artifact. Maintainers approve intentional changes by committing the new snapshots.
- Run on **every PR**.

### L5 — End-to-end user journeys (XCUITest, label-gated)
- Behavioral end-to-end coverage of complete user tasks: open app → search → tap recipe → save → cook mode → back. Asserts a meaningful end-state after a multi-screen walk; **not** a reachability check (L3's job) and **not** a pixel-level visual check (L4's job).
- Scheme: `DODAppE2ETests` (separate from `DODAppUITests` so the L3 smoke scheme stays fast and runs every PR).
- Tool: **XCUITest** — the same framework as L3, so the author skillset transfers. No Detox / Maestro / WebDriverAgent — adding a new test-harness dependency family would cost more than it adds (see CL-58).
- Triggers (the four CI surfaces invoked by `.github/workflows/ci.yml` `test-e2e` job):
  1. `pull_request` events on the `main` branch **only when the PR carries the `e2e` label**.
  2. `push` to `main` (post-merge safety net — catches any regression that slipped past the per-PR gates).
  3. `workflow_dispatch` (manual escape hatch from the Actions UI).
  4. `schedule: '0 7 * * *'` (nightly 7am UTC — environment-drift detector that pairs with the existing nightly live-API job in `.github/workflows/nightly-live-api.yml`).
- Selective gating: L5 is the **first** layer the constitution allows to skip on a per-PR basis. The skip is **success**, not failure — the `ci-required` aggregator treats a skipped `test-e2e` the same way it treats every other job that the `ios_sim` path filter excludes on a docs-only PR. Rationale: per-PR CI quota + signal-to-noise on changes that have no behavioral risk a user-journey test could catch. The full predicate lives in CL-58.
- Which PR changes warrant the `e2e` label: navigation/routing, persistence schema, composition root (`App/AppDependencies.swift`, `App/DODApp.swift`, `App/RootView.swift`), widget extension code, Cook Mode state machine, comments/ratings submission path, App Intents / Spotlight / deep-link parser, onboarding flow. The full checklist lives in `CONTRIBUTING.md` § "Does my PR need E2E?".

### Coverage discipline
- No numeric coverage threshold gate.
- Every acceptance criterion in `spec.md` must map to at least one named test across L1–L3. The Validator enforces this. L5 journeys may pin acceptance criteria too but are not required to — the seed five journeys (T-603) overlap with existing L3 surfaces by design.

### CI gates
- L1–L4 run in CI on every PR. Red blocks merge. No `@Test(.disabled)` without a linked issue.
- L5 runs on the four trigger surfaces above. "Skipped" counts as success in the `ci-required` aggregator. "Failed" blocks merge.

## 7. Accessibility

- Dynamic Type supported on every text surface up to AX5.
- VoiceOver labels on every interactive element and every meaningful image.
- Color contrast meets WCAG AA in both light and dark mode.
- Reduce Motion respected for any non-essential animation.
- Accessibility is an acceptance criterion, not a polish item. PRs that regress a11y are blocked.

## 8. Performance budgets

- Cold launch to first interactive frame: **< 1.5s** on iPhone 13.
- Recipe list scroll: 60fps sustained, no dropped frames on iPhone 13.
- Recipe detail open from list tap: **< 300ms** when cached, **< 1.5s** when fetching.
- App size: under **30 MB** install size at v1.0.

## 9. Privacy & security

- **Analytics:** **TelemetryDeck only.** Chosen because it requires no ATT prompt, collects no IDFA, no PII, no cross-app tracking, and ships a small SDK. Any other analytics SDK (Google Analytics/Firebase, Mixpanel, Amplitude, etc.) is **prohibited** in v1 and requires a constitution amendment.
  - Events tracked are limited to: app open, screen view, recipe view, recipe save/unsave, search query (query string hashed, not raw), share action, offline-read event, cook-mode-started event (recipe ID only, no free-text payload — added by consultant-pass amendment for spec US-7 AC-7.7), `recipeRated(recipeID:stars:)` (added by CL-21 for US-13 AC-13.5 — integer recipe id + integer 1–5 star count, no free text), `recipeCommentSubmitted(recipeID:moderated:)` (added by CL-21 for US-14 AC-14.7 — integer recipe id + bool indicating whether the WP response was `hold` (true) or `approved` (false), no raw comment body), `widgetOpened(kind:recipeID:)` (added 2026-05-24 by the US-17 widget-cluster amendment for spec AC-17.9 — `kind` is the enum string `"featured"` or `"saved"` identifying which home-screen widget surface was tapped, `recipeID` is an integer WP post id when the tap targeted a specific recipe row and is omitted entirely from the payload for chrome / empty-state taps; no free text; replaces the previously-unnamed implicit "widget deep link consumed" routing log and is the canonical event for both widget surfaces going forward), `voiceModeToggled(on:)` and `voiceCommandFired(command:)` (both added 2026-05-27 by the US-40 Voice Mode amendment for spec AC-40.8 — `voiceModeToggled` carries a single boolean `on` (whether Voice Mode was turned on or off in Cook Mode); `voiceCommandFired` carries a single `command` value that is a **fixed enum string** drawn from a closed set — `"next"` / `"previous"` / `"repeat"` / `"pause"` — naming which Siri voice command was invoked, **never** the user's raw spoken phrase. Both are device-state / usage events with no free text and no recipe id; authorized by CL-83), `syncEnabled` / `syncDisabled` / `syncCompletedSuccessfully` / `syncFailed(errorCategory:)` (all added 2026-05-30 by the US-41 CloudKit-sync amendment for spec AC-41.9 — `syncEnabled` fires when the user turns iCloud Sync on via the AC-41.2 first-launch prompt or the AC-41.3 Settings toggle, `syncDisabled` when they turn it off via the toggle, both with **empty** payloads; `syncCompletedSuccessfully` fires at most once per 60s after a successful CloudKit round-trip (empty payload); `syncFailed` carries a single `error_category` value that is a **fixed enum string** drawn from a closed set — `"network"` / `"accountStatus"` / `"quotaExceeded"` / `"serverInternal"` / `"other"` — categorizing the failure, **never** the raw `CKError` code or message. All four are session-level usage events with no PII, no free text, and no recipe id (sync is not a per-recipe action; the existing `recipeSaved` already covers per-recipe granularity); authorized by CL-124).
  - **`screenView(name:)` name allowlist.** The screen-view event's `name` is a **fixed enum string** drawn from a closed set the app defines (never user input) — the same allowlist-safe posture as `widgetOpened`'s `kind` (authorized by CL-83). The tokens are: `feed`, `saved`, `search`, `recipe_detail`, `category_recipes`, and — *added 2026-07-04 by the US-16 / CL-306 (T-912 / DUT-551) navigation restructure* — `cooking_tools` (the new first-class Cooking Tools hub tab). The prior `grocery` and `settings` tab tokens are **retired but historical** — they are no longer emitted from the tab path (their tabs were replaced by the hub + a header Settings gear), but past event counts under those names remain valid.
  - **No** raw user input strings sent to TelemetryDeck. No device identifiers beyond TelemetryDeck's anonymized client hash. The guest-identity name + email (US-15) are **never** sent to TelemetryDeck — they travel only to dutchovendaddy.com over HTTPS.
  - App Privacy "nutrition label" declares: *Usage Data — Product Interaction — not linked to user, not used for tracking;* and, per CL-21, *Contact Info — Email Address* + *User Content — Customer Support* — linked to user, not used for tracking, for App Functionality only. Full mapping table below.
- **Ads & third-party trackers:** none. Ever, without an amendment.
- **Guest identity for comments/ratings:** the app collects a display **name** and **email address** from the user the first time they tap to post a rating or comment (US-15). Both are stored in the iOS Keychain on-device only. The same name + email is sent to dutchovendaddy.com's WP REST `/wp/v2/comments` and `/wp-recipe-maker/v1/rating` endpoints on every subsequent post — these are the standard WordPress fields the blog already uses for comment-by-email moderation. No password, no auth token, no account.
- **App Privacy questionnaire mapping** (per CL-21):

  | Apple category | Specific type | Linked to user? | Used for tracking? | Purposes |
  |---|---|---|---|---|
  | Contact Info | Email Address | Yes (to the user's chosen display name) | No | App Functionality |
  | User Content | Customer Support | Yes | No | App Functionality |
  | Usage Data | Product Interaction | No | No | App Functionality, Analytics |

  Explicit non-collection still true: no password, no IDFA, no device id beyond TelemetryDeck's anonymous client hash. No accounts in v1.
- **App Transport Security:** strict HTTPS only. No exceptions.
- **Secrets:** TelemetryDeck app ID is the only secret in v1. Stored in a gitignored `.xcconfig`, not in source. Never logged.
- **Crash reporting:** Apple's built-in MetricKit only in v1. No Crashlytics/Sentry.
- **App Store compliance:** every release passes through the App Privacy questionnaire honestly; any new data collection requires updating that questionnaire *and* this section before submission.
- **Cook Mode idle-timer:** while Cook Mode (spec US-7) is the foreground surface, the app sets `UIApplication.shared.isIdleTimerDisabled = true` so the screen does not auto-lock during a cook, and restores the prior value on exit. This is a UIKit-level device-state toggle, **not** a tracked event and **not** a new category of data collection — no signal is sent to TelemetryDeck about idle-timer state, and the App Privacy questionnaire is unaffected. Cook Mode entry is tracked separately as an allowlisted `cookModeStarted` event under "Usage Data — Product Interaction" (see §9 event list above and spec US-7 AC-7.7).
- **Local notifications (spec US-42 / T-631):** the "Notify me when new recipes drop" toggle (spec AC-36.1) schedules **on-device local notifications** via `UNUserNotificationCenter` when enabled — there is no Apple Push / APNs, no device token, no remote payload, and no server in v1 (CL-100). The notification content (title, body, the `userInfo` deep-link target) is composed and presented entirely on-device; **nothing about a notification's content, schedule, or a user's tap is sent to TelemetryDeck**, and the App Privacy questionnaire is unaffected — this is a device-local, system-presented affordance in the same spirit as the Cook Mode idle-timer above and the Live Activity payload in §2, **not** a new category of data collection and **not** a tracked event. v1 adds **no** `notificationOpened` (or similar) analytics event; should a future task want a notification-adoption signal, it must amend the §9 allowlist above *and* re-check the App Privacy questionnaire at that time.
- **On-device AI inference (spec US-54 / T-931..T-934, per CL-330):** the optional Apple Intelligence affordances run the on-device FoundationModels LLM (§3) to summarize a recipe/article, suggest a shopping-list ingredient substitution, or answer a Cooking Tools question — all **entirely on-device** (§4.1). This is **not a new category of data collection**: no image, no recipe text, no ingredient text, and no model output is sent off-device, and — mirroring the CloudKit conclusion in CL-94 — **the App Privacy questionnaire is unaffected** (there is no "data collected" to declare because nothing leaves the device; this is even cleaner than CloudKit, which at least sends to the user's own iCloud container). The existing §9 hard rule is **restated and binding here**: the model **input** text (the recipe / article / ingredient / prompt strings) and the model **output** text (summaries, substitutions, answers) are **raw user / content strings and MUST NEVER be sent to TelemetryDeck** — the same "No raw user input strings sent to TelemetryDeck" rule above. v1 of this feature adds **no** analytics event at all. Should a future task want an AI-adoption signal, it must amend the §9 "Events tracked are limited to:" allowlist above with a **fixed-enum, PII-free** event in the same closed-payload posture as `widgetOpened(kind:)` / `voiceCommandFired(command:)` / `syncFailed(errorCategory:)` — e.g. a hypothetical `aiSummaryGenerated(surface:)` whose `surface` is a closed enum (`recipe` / `article` / `shoppingList` / `cookingTools`) and which carries **no** recipe text, no ingredient text, no prompt, and no model output — *and* re-check the App Privacy questionnaire at that time. No specific event is committed to now; that is left to the feature specs (US-54 ships untracked). This is a device-local compute affordance in the same spirit as the Cook Mode idle-timer, the Live Activity payload (§2), and the local notifications above — **not** a tracked event and **not** a new data category.

## 10. Coding standards

- **Formatter:** `swift-format` with the Apple default config, run on pre-commit and in CI.
- **Linter:** `SwiftLint` with project config. Warnings fail CI.
- **Naming:** Apple API Design Guidelines. No Hungarian notation, no `m_` prefixes.
- **File layout:** one top-level type per file unless types are private helpers of the same feature.
- **Comments:** explain *why*, not *what*. No commented-out code in commits.
- **Force-unwraps:** banned outside of tests and `IBOutlet`-style scenarios that don't exist in SwiftUI. Use `guard`/`if let`.
- **TODOs:** must include a date and an owner, or they get removed in review.

### 10.1 Visual consistency — corner radius (two-tier rule, CL-304)

The app's roundness is a **two-tier** system. Every rounded element must fall into one tier — never a one-off literal.

- **Pill tier → `Capsule`:** all buttons (`dodProminentButton` / `dodBorderedButton`, and any custom-styled button background), chips, tags, segmented toggles, and small tappable pills render as a full `Capsule`. **Buttons are pills, not rounded rectangles.**
- **Card tier → `DODRadius.standard`:** cards, list cells, containers, sheets, callouts, dialog cards, and thumbnails use `DODRadius.standard`. That token is **calibrated to match the live iOS `.insetGrouped` list-cell radius** (the Settings-tab reference). Apple changes this radius across major iOS releases — iOS 26 "Liquid Glass" made it notably rounder — so **re-measure and re-pin `standard` per major iOS; never assume a fixed number.** `DODRadius.inner` scales concentrically (`inner ≈ standard − nesting padding`) for content nested inside a card.
- **Exempt:** `Circle` (avatars, step dots), shapes already `Capsule`, and `cornerRadius: 0` skeleton placeholders (CL-288) stay as-is.
- **Never hard-code radius literals** and never reuse `DODSpacing` values for rounding — always `DODRadius.*` (cards) or `Capsule` (pills).

This applies to **every new feature by every contributor**, including any AI assistant working in this repo on either developer's machine. New UI that introduces a rounded button, card, or cell must use the correct tier from the start. Supersedes the pre-CL-304 "everything at `DODRadius.standard` (12pt)" convention (CL-288 / CL-289); the codebase migration to this rule is tracked separately (see the re-sweep task in `tasks.md`).

### 10.2 Copy consistency — Title Case for controls + headings (CL-305)

User-facing **controls and headings use headline-style Title Case**; **body copy stays sentence case**. Codifies the long-standing "Title Case per T-750" convention.

- **Title Case (headline style) — apply to:** button / CTA labels, tab / toolbar / menu / context-menu labels, section headers, navigation & screen titles, list-row labels, and prominent headings — **empty-state titles, alert / confirmation-dialog titles, card titles, sheet titles**.
- **Headline style:** capitalize the first + last word and all major words; keep **small words lowercase** — articles (`a`, `an`, `the`), coordinating conjunctions (`and`, `or`, `but`, `nor`), and short prepositions (`of`, `to`, `in`, `on`, `for`, `at`, `by`, `up`, `as`) — **unless** they are the first or last word. (Verbs like `Is`/`Be`/`Are` stay capitalized — they're not small words.) e.g. "Add Your Name and Photo", "Cook by Feel", "Your Shopping List Is Empty".
- **Sentence case — leave as-is:** body text, descriptions, subtitles, captions, footers, coaching/instruction sentences, empty-state **message** bodies, alert **message** bodies, snackbar/toast sentences, placeholder/helper text.
- **Exempt (don't touch):** all-caps eyebrows ("LATEST RECIPE", "COOKING TIP"), question-form strings ("What are we cooking?"), WordPress/dynamic content (recipe & article titles, category names, ingredient text — shown as authored), and accessibility labels/hints (natural language). Proper nouns / brand names / acronyms keep their canonical casing ("BuzzyWaxx", "iCloud", "DOD").

This applies to **every new feature by every contributor** (both developers + any AI assistant). New user-facing controls/headings must be Title Case from the start. The migration of existing copy is tracked separately (see the Title-Case sweep task in `tasks.md`).

## 11. Git & review process

- **Branches:** `main` is protected. Feature branches: `feat/<slug>`, fixes: `fix/<slug>`, spec changes: `spec/<slug>`.
- **PR size:** each PR maps to exactly one task in `tasks.md`. 1–4 hours of work. Larger PRs are split before review.
- **PR description** links to the spec section and the task entry it implements.
- **Reviewer:** at least one human approval before merge. Validator agent output attached as a comment but does not replace human review.
- **Commits:** conventional commits (`feat:`, `fix:`, `chore:`, `test:`, `spec:`, `refactor:`).
- **No** force-push to shared branches. No squash that loses spec-trace links.

## 12. Spec-driven workflow rules

- Specs are the source of truth. Code that contradicts the spec is a defect — fix the code or update the spec, never both silently.
- Every PR cites the `spec.md` section(s) it implements.
- Post-merge change requests: update the spec first, then plan/tasks deltas, then code. No exceptions.

## 13. Amendment process

To change this document: open a `spec/constitution-amendment-<topic>` branch, edit this file, explain the rationale in the PR description, and get human approval. Amendments take effect on merge and apply only to specs created after the merge date unless explicitly retroactive.
