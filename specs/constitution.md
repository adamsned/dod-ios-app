# Constitution — Dutch Oven Daddy iOS App

Immutable rules. All specs, plans, and tasks must conform. Changes require an explicit constitution amendment, not silent drift.

## 1. Product identity

- Native iOS/iPadOS app for the Dutch Oven Daddy cooking blog (dutchovendaddy.com).
- Primary job: let readers browse, search, save, and cook recipes from the blog on iPhone and iPad.
- Brand: warm, food-forward, readable. Recipes are the hero — chrome is minimal.
- The app is **mostly** read-only: every recipe is a tap away without sign-in. v1.0 adds **two write surfaces** — submitting a rating (1–5 stars) and posting a comment on a recipe — both of which post directly to the dutchovendaddy.com WordPress install via its REST API. No accounts; see §9 for the guest-identity model.

## 2. Platforms & versions

- **Targets:** iPhone and iPad. Universal app, single binary.
- **Minimum OS:** iOS 17 / iPadOS 17.
- **Orientation:** portrait + landscape on iPad; portrait-primary on iPhone (landscape allowed for recipe reading and video).
- **No** watchOS, macOS Catalyst, or visionOS in v1. Revisit after launch.
- **Cook Mode** is in scope for v1.0 (a hands-free, screen-awake cooking surface on recipe detail). Was previously an implicit non-feature; promoted in by the consultant-pass amendment (CL-16, spec US-7). Watch / Mac / Vision targets remain out.
- **Widget extension included** for v1.0 — a WidgetKit extension (`app-extension` target, NSExtensionPointIdentifier `com.apple.widgetkit-extension`, bundle ID `com.dutchovendaddy.DODApp.Widget`) embedded in the host app bundle, surfacing today's featured recipe on the home screen in `systemSmall` and `systemMedium`. Promoted in by the consultant-pass amendment (2026-05-23, spec US-9). Data flows from app to widget via the shared App Group `group.com.dutchovendaddy.DODApp`; no new analytics, no new network endpoints, no PII. Large + Lock Screen accessory families remain out for v1. Watch / Mac / Vision targets still out.
- **ActivityKit (iOS 16.1+)** is used for Cook Mode timers (spec US-11). When a user starts a step timer in Cook Mode, the app pushes a Live Activity so the countdown surfaces on the Lock Screen and (on iPhone 14 Pro and later) in the Dynamic Island. ActivityKit calls are wrapped behind `if #available(iOS 16.1, *)` and guarded with `#if os(iOS)` so the package still builds on the macOS test slice. Pre-iOS 16.1 hosts and users who have disabled Live Activities system-wide degrade silently to the inline timer only (spec AC-11.4). The Live Activity payload (`recipeTitle`, `recipeID`, `remainingSeconds`, `stepText`, `isPaused`) carries no PII and is not telemetry — it is a system-presented countdown, not an event sent to TelemetryDeck, and the App Privacy questionnaire is unaffected (parallel to the idle-timer note in §9).

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

## 4. Content source

- **Primary:** WordPress REST API at `https://dutchovendaddy.com/wp-json/wp/v2/`.
- **Recipe data:** WP Recipe Maker fields where available (`/wp-json/wp/v2/posts` + WPRM endpoints).
- **Offline:** All viewed recipes cached locally. Explicitly saved recipes are guaranteed available offline (images included).
- **No** scraping HTML as a primary source. HTML parsing only as a documented fallback for fields the API does not expose.
- **No** auth required for reads in v1. Anonymous client.

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
  - Events tracked are limited to: app open, screen view, recipe view, recipe save/unsave, search query (query string hashed, not raw), share action, offline-read event, cook-mode-started event (recipe ID only, no free-text payload — added by consultant-pass amendment for spec US-7 AC-7.7), `recipeRated(recipeID:stars:)` (added by CL-21 for US-13 AC-13.5 — integer recipe id + integer 1–5 star count, no free text), `recipeCommentSubmitted(recipeID:moderated:)` (added by CL-21 for US-14 AC-14.7 — integer recipe id + bool indicating whether the WP response was `hold` (true) or `approved` (false), no raw comment body), `widgetOpened(kind:recipeID:)` (added 2026-05-24 by the US-17 widget-cluster amendment for spec AC-17.9 — `kind` is the enum string `"featured"` or `"saved"` identifying which home-screen widget surface was tapped, `recipeID` is an integer WP post id when the tap targeted a specific recipe row and is omitted entirely from the payload for chrome / empty-state taps; no free text; replaces the previously-unnamed implicit "widget deep link consumed" routing log and is the canonical event for both widget surfaces going forward), `voiceModeToggled(on:)` and `voiceCommandFired(command:)` (both added 2026-05-27 by the US-40 Voice Mode amendment for spec AC-40.8 — `voiceModeToggled` carries a single boolean `on` (whether Voice Mode was turned on or off in Cook Mode); `voiceCommandFired` carries a single `command` value that is a **fixed enum string** drawn from a closed set — `"next"` / `"previous"` / `"repeat"` / `"pause"` — naming which Siri voice command was invoked, **never** the user's raw spoken phrase. Both are device-state / usage events with no free text and no recipe id; authorized by CL-83).
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

## 10. Coding standards

- **Formatter:** `swift-format` with the Apple default config, run on pre-commit and in CI.
- **Linter:** `SwiftLint` with project config. Warnings fail CI.
- **Naming:** Apple API Design Guidelines. No Hungarian notation, no `m_` prefixes.
- **File layout:** one top-level type per file unless types are private helpers of the same feature.
- **Comments:** explain *why*, not *what*. No commented-out code in commits.
- **Force-unwraps:** banned outside of tests and `IBOutlet`-style scenarios that don't exist in SwiftUI. Use `guard`/`if let`.
- **TODOs:** must include a date and an owner, or they get removed in review.

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
