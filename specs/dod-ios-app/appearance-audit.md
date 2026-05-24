# Appearance Audit — v1.0 (US-18, T-330)

**Date:** 2026-05-24
**Branch baseline:** `spec/features-16-17-18` @ `9a3b7ce`
**Governs:** constitution §7 (Accessibility — WCAG AA in both appearances), spec US-18 (AC-18.1..AC-18.6), CL-30.

## What this is

Framed per CL-30 as **audit + targeted fixes**, not a feature implementation. The deliverable is the matrix below. Any fix the audit surfaces is logged as a separate T-331+ task — T-330 itself ships only the audit document + the snapshot-baseline gap fills that are closeable in-place by extending an existing test file. Per AC-18.6, a clean audit (or an audit that surfaces only follow-up tasks, no inline fixes) is an acceptable outcome.

## What was audited

- Top-level screens called out by AC-18.1: Feed, Categories list, Category detail, Search, Recipe detail (including the ratings/comments section from US-13/14/15), Saved, Cook Mode, Onboarding.
- Live Activity surfaces (US-11 lock screen + Dynamic Island compact pieces) — adjacent to recipe detail and covered by the existing `CookLiveActivitySnapshotTests`.
- Home-screen widget surfaces (US-9 today's-featured small/medium/placeholder) — covered by `WidgetCard` snapshot tests in DesignSystem. **US-17 saved-recipes widget** (added by the same spec PR that introduced US-18) is documented as a follow-up because its implementation hasn't landed yet on this branch.
- Every component in `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/`: `CommentComposer`, `CommentRow`, `EmptyState`, `GuestIdentitySheet`, `LoadingSkeleton`, `ModerationBadge`, `OfflineBanner`, `OnboardingSheet`, `RecipeCard`, `Snackbar`, `StarRating` (display + input), `WidgetCard` (small + medium + placeholder).

## What was NOT audited (and why)

- **Rendered contrast values** — the audit doc cannot read PNG pixel colors and verify WCAG AA computed against rendered tokens (AC-18.4). Cells marked "snapshot present" rely on the human PR reviewer opening the PNG, or on Accessibility Inspector during the manual sweep that constitution §7 + `accessibility-audit.md` already mandate before any TestFlight build. Tokens with light + dark catalog entries are documented in `accessibility-audit.md` (Label/LabelSecondary on Surface, Cream on CastIronBrown). Two pairs are flagged there as "need to verify in Accessibility Inspector" — that verification step is the human checkpoint, not this audit.
- **Reduce-Transparency** (AC-18.5) — `LoadingSkeleton` already wires `@Environment(\.accessibilityReduceMotion)` (verified in source). Reduce-Transparency has no current consumer in the design system (no `Material` or `.ultraThinMaterial` backgrounds in any component or top-level screen). Audited as a no-op for v1.0.
- **Reduce-Motion** — covered by `accessibility-audit.md` already; this audit doesn't duplicate that verification.
- **US-17 saved-recipes widget** (`SavedRecipesWidgetSnapshotTests`) — file doesn't exist on this branch yet; it's a Phase 8 deliverable from T-320..T-323. Once that lands, the same dark + AX5 expansion proposed for the existing `WidgetCard` baselines should extend to the saved variant.

## Coverage matrix — surfaces (US-1..US-15)

Cells: `L=light`, `D=dark`, `defT=default Dynamic Type`, `AX5=AX5 Dynamic Type`. `present` means a baseline PNG is committed and diffed on every CI run; `missing` means no committed PNG; `n/a` means not applicable.

| Surface | Source file | L/defT | D/defT | L/AX5 | D/AX5 |
|---|---|---|---|---|---|
| US-1 Feed | `Packages/DODFeatureFeed/Sources/DODFeatureFeed/FeedView.swift` | missing | missing | missing | missing |
| US-2 Categories list | `Packages/DODFeatureCategories/Sources/DODFeatureCategories/CategoryListView.swift` | missing | missing | missing | missing |
| US-2 Category detail | `Packages/DODFeatureCategories/Sources/DODFeatureCategories/CategoryRecipesView.swift` | missing | missing | missing | missing |
| US-3 Search | `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift` | missing | missing | missing | missing |
| US-4 Recipe detail | `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/RecipeDetailView.swift` | missing | missing | missing | missing |
| US-5 Saved | `Packages/DODFeatureSaved/Sources/DODFeatureSaved/SavedView.swift` | missing | missing | missing | missing |
| US-7 Cook Mode | `Packages/DODFeatureRecipeDetail/Sources/DODFeatureRecipeDetail/CookModeView.swift` | missing | missing | missing | missing |
| US-8 Onboarding | `OnboardingSheet` (component) | present (`test_onboardingSheet_default`) | extended (this PR, `record: .missing`) | extended (this PR, `record: .missing`) | missing |
| US-9 Widget — small | `WidgetCard.Small` (component) | present (`test_widgetCard_small_populated`) | extended (this PR) | n/a (widget sizes are fixed; no Dynamic Type scaling on home screen) | n/a |
| US-9 Widget — medium | `WidgetCard.Medium` | present (`test_widgetCard_medium_populated`) | extended | n/a | n/a |
| US-9 Widget — placeholder | `WidgetCard.Placeholder` | present (`test_widgetCard_placeholder`) | extended | n/a | n/a |
| US-11 Cook Live Activity (lock screen) | `CookActivityLockScreenView` | test exists; **PNGs not committed** | missing | missing | missing |
| US-11 Cook Live Activity (Dynamic Island compact) | `CookActivityCompactLeading/TrailingView` | test exists; **PNGs not committed** | n/a (system controls Dynamic Island Dynamic Type) | n/a | n/a |
| US-12 Ingredient filters chips | inside `SearchView` | missing (covered transitively by US-3 row) | missing | missing | missing |
| US-13/14/15 Ratings + comments section | `RecipeDetailRatingsSection` | present (`test_section_*` ×3) | missing | missing | missing |
| US-16 Tab bar (Saved promoted) | `App/TabStack.swift` | missing | missing | missing | missing |
| US-17 Saved-recipes widget | not yet on this branch | n/a (deferred) | n/a | n/a | n/a |

## Coverage matrix — DesignSystem components (AC-18.2)

| Component | L/defT | D/defT | L/AX5 | D/AX5 |
|---|---|---|---|---|
| `CommentComposer` (empty) | present | missing | missing | missing |
| `CommentComposer` (filled) | present | extended (this PR, `record: .missing`) | missing | missing |
| `CommentRow` (with avatar + rating) | present | extended | extended | missing |
| `CommentRow` (pending moderation) | present | missing | missing | missing |
| `CommentRow` (long body) | present | missing | missing | missing |
| `EmptyState` (default) | present | extended | missing | missing |
| `EmptyState` (with action) | present | extended | extended | missing |
| `GuestIdentitySheet` (empty) | present | missing | missing | missing |
| `GuestIdentitySheet` (filled valid) | present | extended | missing | missing |
| `LoadingSkeleton` | n/a — animated; static-fill fallback covered indirectly by Reduce Motion path | n/a | n/a | n/a |
| `ModerationBadge` (each kind) | present | extended | missing | missing |
| `OfflineBanner` (offline) | present | extended | missing | missing |
| `OnboardingSheet` (default) | present | extended | extended | missing |
| `RecipeCard` (full) | present | extended | extended | missing |
| `RecipeCard` (no time chip) | present | missing | missing | missing |
| `RecipeCard` (half-width) | present | extended | missing | missing |
| `Snackbar` (plain) | present | extended | missing | missing |
| `Snackbar` (with undo) | present | extended | missing | missing |
| `StarRatingDisplay` (4.5 stars, 27 count) | present | extended | missing | missing |
| `StarRatingDisplay` (zero count empty) | present | missing | missing | missing |
| `StarRatingInput` (zero) | present | missing | missing | missing |
| `StarRatingInput` (three stars) | present | extended | missing | missing |
| `WidgetCard.Small` | present | extended | n/a | n/a |
| `WidgetCard.Medium` | present | extended | n/a | n/a |
| `WidgetCard.Placeholder` | present | extended | n/a | n/a |

## Gaps filled by this PR

Added new test class `DesignSystemAppearanceSnapshotTests` in `Packages/DODDesignSystem/Tests/DODDesignSystemTests/SnapshotTests+AppearanceAudit.swift` (a sibling to the existing `DesignSystemSnapshotTests` — the split keeps `SnapshotTests.swift` under SwiftLint's 600-line file cap):

- Added **16 dark-mode variants** (`*_dark`), one for each light test that has a meaningful contrast surface, using a shared `darkTraits()` helper that flips `UITraitCollection.userInterfaceStyle` to `.dark`. Pairs 1:1 with the matching light test so the appearance flip is the only visual delta.
- Added **4 AX5 Dynamic Type variants** (`*_AX5`) on the text-heavy components where Dynamic Type scaling matters most: `RecipeCard`, `EmptyState (with action)`, `CommentRow`, `OnboardingSheet`. Larger fixed-height frames to accommodate AX5 wrap. Light appearance — dark × AX5 is documented below as a deferred cell.
- Each new test uses `record: .missing`, so the first iOS test run lays down the baseline PNG and the second run starts diffing. No PNGs are committed by this PR — that's the simulator-bound follow-up (T-331).

Verified that the new file compiles cleanly under `xcodebuild build-for-testing -scheme DODDesignSystem -destination 'platform=iOS Simulator,name=iPhone 17'`. The package's `swift test` (macOS) continues to pass; the visual tests are guarded by `#if canImport(UIKit)` and only execute under the iOS test action.

Net effect: the `extended (this PR, record: .missing)` cells in the matrix above become `present` after a single sim-side `xcodebuild test -scheme DODDesignSystem` pass, with no human visual review required (the PNGs simply lay down, and become diffable on the next CI run).

## Surfaces requiring human visual review

These cells say "snapshot present" but the audit can't verify whether the rendered output looks right — only the human reviewer can:

- **Existing committed PNGs** (light/defT) in `Packages/DODDesignSystem/Tests/DODDesignSystemTests/__Snapshots__/SnapshotTests/` and `Packages/DODFeatureRecipeDetail/Tests/DODFeatureRecipeDetailTests/__Snapshots__/RecipeDetailRatingsViewSnapshotTests/`. The PR reviewer should spot-check at least one per component — the rest are guaranteed identical to the committed image by the snapshot harness itself.
- **The `extended (this PR)` cells** become "snapshot present" after a follow-up simulator run lays down the new dark + AX5 baselines. The first reviewer of *that* PR should open each new PNG and verify nothing has obviously broken (e.g. a token loses contrast in dark, or AX5 wrap produces truncation).
- **The two contrast pairs flagged in `accessibility-audit.md`** ("Cream on BurntOrange (accent button)" and "WarmGold on CastIronBrown (snackbar Undo)") are still "need to verify in Accessibility Inspector" — that verification is the human checkpoint constitution §7 already requires before TestFlight; this audit does not duplicate it.

## Follow-up tasks recommended

The audit surfaces several gaps that **cannot be closed in-place** by extending an existing test file. Each is logged as a T-331+ entry in `tasks.md`. None of these are blocking US-18 closure — per AC-18.6, US-18 closes with this audit doc + the extended DesignSystem snapshot tests above; the follow-ups elaborate the work the audit surfaced.

- **T-331** — Commit dark + AX5 baseline PNGs for DODDesignSystem (sim run). Run `xcodebuild test` in record mode against the extended `SnapshotTests.swift`, commit the resulting PNGs under `__Snapshots__/SnapshotTests/`, verify each looks correct in both appearances. Pure baseline harvest — no source changes to the component implementations.
- **T-332** — Top-level screen snapshot tests for feature packages. Stand up new snapshot test files in `DODFeatureFeed`, `DODFeatureCategories`, `DODFeatureSaved`, `DODFeatureSearch`, and `DODFeatureRecipeDetail` (root view, not just the ratings section). Each covers L/D × defT/AX5. Requires SnapshotTesting dep added to feature-package `Package.swift` files (currently only `DODDesignSystem` and `DODFeatureRecipeDetail` declare it). New stateful hosts to construct `*ViewModel` in known states without going through real dependencies.
- **T-333** — Commit Cook Live Activity baselines. The existing `CookLiveActivitySnapshotTests.swift` defines five tests but no PNGs are committed yet — the test file ships with `isRecording = false`, so on first CI run they all fail. A sim record pass to lay down the baselines (light) + extend with dark variants for the lock-screen view, then commit.
- **T-334** — Tab bar appearance baseline (US-16). Once `TabStack` changes land for US-16, snapshot the assembled tab bar in both appearances. Single-file follow-up colocated with whatever package owns the new `TabStack`.

If at PR-review time the human reviewer wants any of these compressed into US-18 directly, they can be — T-330's role is to surface them, not gatekeep.

## Resolution: was anything broken?

**No source changes to component implementations or token values are recommended by this audit.** Every component already has light + dark catalog entries in `Colors.xcassets` (per `accessibility-audit.md` §"Color contrast"). The audit's recommendation is **expand the regression surface**, not **fix a contrast bug** — there's no current evidence of a contrast bug; just gaps in the baseline coverage that would let one slip through silently. That distinction is what AC-18.6 ("clean audit allowed") authorizes here.

## Updating this audit

If you add a new top-level screen or a new `DesignSystem/Components/*` component, add the corresponding row(s) to the matrices above in the same PR. Update the "Gaps filled by this PR" section if you close any of the `missing` cells. Constitution §6 + §11.
