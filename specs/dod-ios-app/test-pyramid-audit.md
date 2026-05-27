# Test Pyramid Audit — Phase 11 (T-600)

**Date:** 2026-05-26
**Branch baseline:** `feat/T-400-test-pyramid-l5-e2e` off `origin/main` @ `ed68b32`
**Governs:** constitution §6 (test pyramid), [`spec.md`](spec.md) "Test pyramid" section (post-Phase-6 amendment), [`tasks.md`](tasks.md) Phase 11 cluster.

## What this is

Framed per the same convention as `appearance-audit.md` / `accessibility-audit.md` / `widget-appearance-audit.md`: an inventory of the current test pyramid, a single recommendation, and a follow-up task list. The deliverable is the matrix + the "what's missing" finding. Code changes are tracked separately as T-602..T-605 in [`tasks.md`](tasks.md).

The repository already has four test layers (L1 unit, L2 live-API integration, L3 UI smoke, L4 visual snapshot) per constitution §6. The audit finds that what the constitution calls L3 "UI smoke" is doing **two distinct jobs**: lightweight nav coverage on every PR (the smoke job's actual contract) **and** the longer user-journey assertions a true end-to-end layer would carry. The eight-method `UITests/SmokeTests.swift` file ranges from a 2-second tab-bar reachability check to a 45-second feed-→-detail-→-Cook-Mode walk; that's a smoke test and an E2E test sharing a scheme, gated by a single per-PR CI job. The audit recommends splitting them: keep L3 as the small fast per-PR net, add **L5 E2E** as a label-gated longer suite that runs on push to main, nightly, and on opt-in PR labels.

## Layer inventory

Cells: `who adds=who is expected to add tests at this layer when a given PR type lands`, `runs on=which CI surfaces invoke it`.

| Layer | What it asserts | Tool | Lives in | Runs on | Who adds when |
|---|---|---|---|---|---|
| **L1 Unit** | Pure logic — view models, networking parsers, domain transforms, persistence rules — against fakes and fixtures. Tagged Swift Testing for new code per constitution §6. | Swift Testing (`import Testing`) + `swift test` per package; XCTest for the host-app slice. | `Packages/<Feature>/Tests/` (10 packages); `AppTests/` for app-target types like `AppTab`. | **Every PR** — `test-unit-packages` job (collapsed serial macOS job, see CI cost note in `.github/workflows/ci.yml:75`) + `test-unit-app` job (iOS-Sim, gated by `ios_sim` path filter). | Every feature, bug fix, or refactor PR. |
| **L2 Live-API integration** | The live WordPress REST API at `https://dutchovendaddy.com/wp-json/wp/v2/*` returns the contract the parsers assume. Catches the kind of drift that fakes can't (REG-2: the `_fields` + `_embed` interaction that emptied hero images; REG-16: new-recipe surfacing; REG-18: URLCache + Cloudflare cache bypass). | Swift Testing (`@Suite(.enabled(if: …))`) + `swift test`. | `Packages/DODIntegrationTests/Tests/DODIntegrationTestsTests/LiveAPITests.swift` (~7 tests, gated by `DOD_RUN_LIVE_TESTS=1`). | **Nightly** via `.github/workflows/nightly-live-api.yml` (cron `0 7 * * *`) + manual `workflow_dispatch`. Skipped on every PR — too flaky against the live blog and CI quota is tight. Auto-files a GH issue if it goes red. | Anyone whose PR changes the WP REST schema assumptions (new endpoint, new field, new fallback). Reads from prod only — never POSTs. |
| **L3 UI Smoke** | The app launches on a fresh sim and the golden path works end-to-end: tab bar appears, four tabs reachable, feed loads with at least one image, recipe detail pushes, Cook Mode can advance one step. Catches launch-on-fail and missing-content regressions (REG-1, REG-2 surface-side, REG-DOD-NAV-1, REG-DOD-LIST-SCROLL). | XCUITest, scheme `DODAppUITests`. | `UITests/SmokeTests.swift` (8 methods, ~330 LOC), `UITests/RecipeDetailRatingsSmokeTests.swift` (1 method, ratings section visible). | **Every PR** — `test-ui-smoke` job gated by `ios_sim` path filter. Required for merge. | Anyone whose PR touches the nav/routing surface (new tab, new route, new modal). |
| **L4 Visual regression** | Pixel-locked PNG baselines for every reusable `DesignSystem` component + key feature views in light/dark × default-DT/AX5 × iPhone-13/iPad-12.9", plus all three widget surfaces and the Live Activity lock-screen + Dynamic Island compact views. Failing PNG = visible diff in CI artifact; intentional diffs ship by committing the new baseline. | `pointfreeco/swift-snapshot-testing`. | `Packages/DODDesignSystem/Tests/DODDesignSystemTests/` — `SnapshotTests.swift`, `SnapshotTests+AppearanceAudit.swift`, `LockScreenWidgetSnapshotTests.swift`, `SavedWidgetSnapshotTests.swift`, `TabBarSnapshotTests.swift`, `WidgetCardTintedAppearanceSnapshotTests.swift`, `ComponentsTests.swift`, `ColorsTests.swift`; per-feature `__Snapshots__/` directories ship the PNGs. | **Every PR** — `test-snapshots-designsystem` job gated by `ios_sim` path filter. Required for merge. | Anyone whose PR touches a design token, a component, or any view that renders into a snapshot baseline. |

## The L3 / E2E gap

`UITests/SmokeTests.swift` is doing two jobs:

- **Pure smoke** (under 3s each): `test_appLaunchesWithoutTelemetryAppID`, `test_allFourTabsAreReachable`, `test_tabBarOrderMatchesSpec`, `test_savedTabEmptyStateOnFreshInstall`. These are reachability assertions, not user-journey assertions — they answer "did the app come up and is the chrome where the spec says it should be?"
- **De-facto end-to-end** (15–45s each, hitting the live blog): `test_recipeDetailOpensAndShowsContent`, `test_feedShowsAtLeastOneRecipe`, `test_feedRecipesHaveImages`, `test_cookModeOpensAndAdvances`, `test_onboardingShowsOnFirstLaunchAndDismisses`, `test_feedScrollsToRevealMoreRecipes`. These walk a real-feeling user task to completion and assert state at the far end.

This mixing has three concrete costs:

1. **CI minutes**. The `test-ui-smoke` job billed time scales with the slowest test, not the average. A 2s tab-bar test and a 45s Cook-Mode walk in the same scheme mean every PR pays the 45s — even a docs-touch-adjacent PR that just wants the smoke contract green.
2. **No gating policy**. A PR that touches a SwiftUI color token doesn't need a Cook-Mode walk to merge — but the current scheme makes that all-or-nothing. The "should I add an E2E test?" question has no formal answer because the layer that would carry the test doesn't have a name distinct from "smoke."
3. **Live-blog flake bleed-in**. The journey tests load real WP feed posts (the smoke job runs without `DOD_RUN_LIVE_TESTS=1` but still hits the real blog at app launch because the production code paths are unswitched). One slow-loading blog response and the per-PR smoke job goes red on a recipe-card-color PR. The L2 job is nightly precisely to keep this kind of flake out of the per-PR path; the de-facto-E2E half of L3 contradicts that policy.

## Recommendation: add L5 E2E as a fifth layer

Add a **fifth** layer to the pyramid for behavioral end-to-end user-journey coverage. L3 stays as-is (fast, every PR), L5 is separate (slower, label-gated). Keep XCUITest as the tool — switching to Detox/Maestro/WebDriverAgent would add a new dependency family for zero coverage gain.

### Proposed L5 — End-to-end user journeys

| Field | Value |
|---|---|
| **What it tests** | Complete user journeys: open app → search → tap result → save → cook → back. Asserts an end-state, not chrome reachability. |
| **Tool** | XCUITest (same framework as L3 — keeps the test author skillset shared, no new dep). |
| **Scheme** | `DODAppE2ETests` (separate from `DODAppUITests` so the L3 smoke scheme stays fast). |
| **Target location** | `UITests/E2E/` (new subdirectory). Same `UITests/` parent so the test-bundle infra is shared, but the source root that the scheme compiles is gated. |
| **Test-data strategy** | Deterministic launch via `XCUIApplication.launchArguments += ["-DOD_E2E_MODE=1"]` + `launchEnvironment["DOD_E2E_MODE"] = "1"`. **Phase 1 (this work, T-602):** ship the launch-argument stub; the host app reads the flag at boot and records it into a process-wide `DODEnvironment.isE2EMode` boolean. The boolean does **not yet** swap dependencies — the seed journeys in T-603 drive against the existing production code paths (same as the existing L3 smoke job today). **Phase 2 (follow-up, T-610):** wire a `FakeAppDependencies` so when `DOD_E2E_MODE=1` the host app swaps in canned fixtures — no live network, no SwiftData state from previous runs. Documented in this audit so the gap is visible. |
| **When it runs** | (1) `pull_request` with the `e2e` label, (2) `push` to `main`, (3) `workflow_dispatch`, (4) nightly cron `0 7 * * *`. Skipped on every PR by default. |
| **What's a typical L5 test** | "Open the app fresh → tab into Search → type a query → see results → tap first → see detail with title visible." Five seed journeys ship in T-603; future PRs add more as the feature surface grows. |
| **What's NOT L5** | Visual regression (L4's job — XCUITest can't read pixels reliably). Pure logic (L1's job). API contract drift (L2's job). |

### Selective gating policy — why "not every PR needs E2E"

Per constitution §6 ("All four layers run in CI. Red blocks merge."), the constitution is the source of truth on which layers gate merge. The proposed L5 is the **first** layer where we deliberately break that "every PR" rule, for two reasons:

1. **CI quota**. The user is on a tight macOS-minutes budget. A 5-journey × ~25s × ~3-minute scheme-boot overhead on every PR is ~5 min × per push. With ~3 PRs/day that's 30+ min/day, ~15 hours/month. The label-gated approach uses E2E minutes only where they're load-bearing.
2. **Signal-to-noise**. Pure-docs PRs, lint fixes, single-package refactors, and CI-yaml tweaks have no behavioral risk a user-journey test can find. Running E2E on those PRs adds wall-clock without adding coverage value.

The policy lives in [`CONTRIBUTING.md`](../../CONTRIBUTING.md) under the new "Does my PR need E2E?" section (T-605). The label is `e2e` on the PR; CI picks it up and runs `test-e2e`. PRs without the label see `test-e2e` show "skipped" in the `ci-required` aggregator, which is treated as success (same pattern the `ios_sim` path filter uses for docs-only PRs).

A PR **needs** the `e2e` label if it touches:

- Navigation/routing surfaces (tab bar, `NavigationStack` pushes, deep links).
- Persistence schema changes (SwiftData migration risk).
- Composition root (`App/AppDependencies.swift`, `App/DODApp.swift`, `App/RootView.swift`).
- Widget extension code or widget/host coordination.
- Cook Mode state machine.
- Comments/ratings submission path.
- App Intents / Spotlight indexing / deep-link parser.
- Onboarding flow.

A PR **does not** need the `e2e` label if it's:

- Pure docs/spec.
- Tests-only changes.
- Lint/format/CI-yaml fixes (excepting the CI yaml that owns the E2E job itself).
- A single-package refactor with no behavior change.
- A bug fix proven by a regression test at L1 or L2.

## Followups surfaced by this audit (deliberate)

These are scoped out of T-600..T-605 and tracked separately:

- **T-610 — Host-side `DOD_E2E_MODE` fake-dependencies switch.** Wire `App/AppDependencies.swift` (or a new `FakeAppDependencies.swift`) to read `DOD_E2E_MODE=1` at launch and swap in canned `WPRestClient` / `RecipeStore` fixtures so the E2E suite runs hermetically. Until this lands, the seed journeys in T-603 drive against the live blog the same way the existing L3 smoke does — which is acceptable for the first five tests but will fight us as the suite grows.
- **T-611 — L5 coverage of comments/ratings POST path** against a stubbed `WPCommentsClient` once T-610 lands. POSTing to dutchovendaddy.com from CI is explicitly out of scope (the existing L2 suite is read-only; the same constraint applies to L5). A fake is the only way to cover the full submission path.
- **T-612 — Migrate the de-facto-E2E methods out of `UITests/SmokeTests.swift`** into `UITests/E2E/`. Specifically the Cook-Mode walk (`test_cookModeOpensAndAdvances`, 45s), the feed-→-detail open (`test_recipeDetailOpensAndShowsContent`, 45s), and the onboarding dismissal (`test_onboardingShowsOnFirstLaunchAndDismisses`). The original spec-trace links (AC-7.1..AC-7.7, REG-DOD-NAV-1) follow the test method, not the file. Doing this in T-603's commit would be a riskier diff than the audit-and-shim approach taken here; T-612 is the second pass after the L5 scheme has proven green over a week of normal merges.

## Spec-trace summary

| Constitution / spec section | Phase 11 amendment |
|---|---|
| constitution §6 "Testing — required for every PR" | append L5 to the layer table; L5 is the **first** layer with selective gating. |
| `spec.md` "Test pyramid" (Phase 6 amendment block) | append AC-T5 covering the L5 layer + the four trigger surfaces (`e2e` label, push to main, workflow_dispatch, nightly). |
| `clarifications.md` | new CL-58 capturing the rationale: why selective gating (CI quota + signal-to-noise), why XCUITest over Detox/Maestro (no new dep family), why exactly four trigger surfaces, what we deliberately said NO to (no E2E baseline-PNG drift; no live-blog writes; no Android). |
| `tasks.md` | new Phase 11 cluster (T-600..T-605) appended after the existing Phase 10. |
