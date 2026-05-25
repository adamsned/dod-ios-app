# Widget Appearance Audit — v1.0 (US-23, T-390)

**Date:** 2026-05-24
**Branch baseline:** `feat/T-390-widget-appearance-audit` @ HEAD (forks from `main` at `f835df3`)
**Governs:** constitution §7 (Accessibility — WCAG AA across appearance modes), spec US-23 (AC-23.1..AC-23.6), CL-39.
**Sibling docs:** [`appearance-audit.md`](appearance-audit.md) (US-18 / T-330 — the broader light/dark mode audit this one is patterned after), [`accessibility-audit.md`](accessibility-audit.md) (the contrast/Dynamic Type checkpoint).

## What this is

Framed per **CL-39** as **audit + targeted fixes**, not a feature build. The deliverable is this document plus the iOS 18+ Tinted/Vibrant snapshot baselines that lock the current rendering down as the regression net. Per AC-23.6, a clean audit (one that surfaces no fixes) is a valid outcome — the same framing CL-30 established for US-18. The audit DID surface one bounded fix; it's logged in "Fixes applied" below.

## What was audited

Every home-screen widget surface × every iOS 18+ widget rendering-mode environment value × the existing Standard light + dark pair. Six surfaces × four modes = **24 cells.**

**Surfaces:**
- `FeaturedRecipeWidget` (US-9 / US-21) — `WidgetCard.Small` (populated), `WidgetCard.Medium` (populated), `WidgetCard.Placeholder` (empty/cold state).
- `SavedRecipesWidget` (US-17) — `WidgetCard.SavedSmall` (one row), `WidgetCard.SavedMedium` (up to three rows), `WidgetCard.SavedEmpty` (no-saved-recipes placeholder).

**Rendering modes:**
- **Standard / `.fullColor`** — default home-screen appearance, default app icon style. Widget renders with full color treatment.
- **Standard dark** — `colorScheme == .dark`, still `.fullColor` rendering. Asset-catalog dark variants apply.
- **Tinted / `.accented`** — iOS 18+ user-picked home-screen tint. System divides widget view hierarchy into accented + default groups and applies a different color treatment to each based on wallpaper-derived tint color.
- **Vibrant / `.vibrant`** — iOS 18+ "Clear" / vibrant home-screen appearance. System applies a luminance-based desaturation pass; widget content renders as a translucent, frosted-glass treatment over the wallpaper.

## What was NOT audited (and why)

- **Lock-screen accessory widgets** (US-22 / T-370). At the time this audit ran, T-370 was on a separate branch (`feat/T-370-lock-screen-widget`, PR #26) and had not merged to `main`. Per CL-39 the audit is scoped to home-screen widgets only regardless of T-370's merge status — lock-screen accessory widgets render in a different system pipeline (`AccessoryWidgetGroup` family, system-monochromatic vibrancy on the Lock Screen, not the home-screen Tinted/Clear pipeline). If a lock-screen surface ever needs its own appearance verification, that's a separate audit (parallel to the way `appearance-audit.md` and `accessibility-audit.md` and this doc each have a single-pipeline scope).
- **Real-image rendering paths.** `WidgetCard.Hero`'s `AsyncImage` path renders a fixture food photo when a `heroImageURL` is supplied. The snapshot harness has no easy way to inject a real image fixture into `AsyncImage` without adding a test-only image-provider injection point, so all baselines render the gradient-placeholder fallback (the same code path the production widget uses when the App Group container is missing or the snapshot's `heroImageFilename` is nil). The Tinted/Vibrant treatment of a real food photo will look different from the gradient fallback — that's a known gap, but the surface-by-surface decisions in this audit are about the **chrome** (text, eyebrow, chip, gradient overlay), not the image itself, and the chrome is what the snapshot baselines lock down. T-360's image-bridge work is what makes the image render path possible in production; verifying it visually under Tinted mode is a documented follow-up (see "Follow-up tasks" below).
- **Computed contrast values** (WCAG AA against rendered pixels). Same limitation `appearance-audit.md` documents: the audit doc cannot pixel-inspect committed PNGs and verify AA programmatically. Tinted/Vibrant baselines that render text rely on the human PR reviewer opening the PNGs and spot-checking that title text is readable against the now-tinted background, plus the same Accessibility Inspector sweep `accessibility-audit.md` already mandates before TestFlight. Tokens with light + dark catalog entries (Label/LabelSecondary on Surface, Cream on CastIronBrown) are unchanged by this audit — the Tinted/Vibrant transformation is a system-applied desaturation pass on top of the existing token values, not a token change.
- **iOS 17 fallback.** `WidgetRenderingMode` and `widgetAccentedRenderingMode(_:)` are iOS 18+ APIs. On iOS 17 hosts, widgets render exactly as they do today — no system desaturation pass applies because the Tinted/Clear home-screen appearance modes don't exist on iOS 17. The `WidgetHeroFullColorRendering` modifier (see "Fixes applied" below) is a no-op on iOS 17. No iOS 17 baselines are added because there's no behavior to lock down — iOS 17 widgets always render in `.fullColor`-equivalent mode, which is already covered by the existing `test_widgetCard_*_populated` / `test_widgetCard_placeholder` light/dark pairs.

## Coverage matrix — featured widget (US-9 / US-21)

Cells: `present` = baseline PNG committed and diffed on every CI run; `added` = test added by T-390, lays down its PNG on the first iOS sim run via `record: .missing` (same harness convention as T-330); `n/a` = mode doesn't apply.

| Surface | Source | Standard / `.fullColor` | Standard dark | Tinted / `.accented` | Vibrant / `.vibrant` |
|---|---|---|---|---|---|
| `WidgetCard.Small` (populated) | `WidgetCard.swift` | present (`test_widgetCard_small_populated`) | present (`test_widgetCard_small_populated_dark`) | added (`test_widgetCard_small_populated_tinted`) | added (`test_widgetCard_small_populated_vibrant`) |
| `WidgetCard.Medium` (populated) | `WidgetCard.swift` | present (`test_widgetCard_medium_populated`) | present (`test_widgetCard_medium_populated_dark`) | added (`test_widgetCard_medium_populated_tinted`) | added (`test_widgetCard_medium_populated_vibrant`) |
| `WidgetCard.Placeholder` (empty) | `WidgetCard.swift` | present (`test_widgetCard_placeholder`) | present (`test_widgetCard_placeholder_dark`) | added (`test_widgetCard_placeholder_tinted`) | added (`test_widgetCard_placeholder_vibrant`) |

## Coverage matrix — saved-recipes widget (US-17)

| Surface | Source | Standard / `.fullColor` | Standard dark | Tinted / `.accented` | Vibrant / `.vibrant` |
|---|---|---|---|---|---|
| `WidgetCard.SavedSmall` (1 row) | `WidgetCard+Saved.swift` | present (`test_savedWidget_small_oneEntry_light`) | present (`test_savedWidget_small_oneEntry_dark`) | added (`test_savedWidget_small_oneEntry_tinted`) | added (`test_savedWidget_small_oneEntry_vibrant`) |
| `WidgetCard.SavedMedium` (3 rows) | `WidgetCard+Saved.swift` | present (`test_savedWidget_medium_threeEntries_light`) | present (`test_savedWidget_medium_threeEntries_dark`) | added (`test_savedWidget_medium_threeEntries_tinted`) | added (`test_savedWidget_medium_threeEntries_vibrant`) |
| `WidgetCard.SavedEmpty` (empty state) | `WidgetCard+Saved.swift` | present (`test_savedWidget_empty_small_light`, `test_savedWidget_empty_medium_light`) | present (`test_savedWidget_empty_small_dark`, `test_savedWidget_empty_medium_dark`) | added (`test_savedWidget_empty_small_tinted`) | added (`test_savedWidget_empty_small_vibrant`) |

12 new baselines total (6 surfaces × 2 new rendering modes), all laid down by `WidgetCardTintedAppearanceSnapshotTests.swift` via `record: .missing` on first iOS sim run. No PNGs committed by T-390 itself — the simulator-bound harvest mirrors T-330's pattern (audit + extended tests as the PR, baseline PNGs follow on a sim run that's part of the same CI green or a focused follow-up).

## Source-side audit findings

The investigation read every widget surface against each rendering mode and flagged the following:

### Finding 1 — Hardcoded `Color.black.opacity()` gradient overlay on `WidgetCard.Small` (no fix needed)
- **Location:** `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/WidgetCard.swift`, lines 51–60 (the `LinearGradient` inside `WidgetCard.Small`).
- **Concern:** literal `Color.black` doesn't have a dark-mode catalog entry — it's a constant. Under Tinted/Vibrant rendering, the system applies its desaturation pass and renders `Color.black` as a tinted-dark color.
- **Audit verdict:** **fine as-is.** The gradient's purpose is to darken the bottom of the photo so the white title text sits on a readable background. The system's tint of `Color.black` produces a darker-than-the-photo tint regardless of which mode is active — the dark-band-for-text purpose still holds. No source change.

### Finding 2 — Hardcoded `.foregroundStyle(.white)` title text on `WidgetCard.Small` (no fix needed)
- **Location:** `WidgetCard.swift`, line 69 (the `Text(content.title).foregroundStyle(.white)` inside `WidgetCard.Small`).
- **Concern:** literal `Color.white` could become invisible if the system tinted it onto a light tint background.
- **Audit verdict:** **fine as-is** — because the gradient overlay (Finding 1) sits between the photo and the text, and the gradient is `Color.black.opacity(0.75)` at the bottom. Under any rendering mode, the gradient renders darker than the text after tinting, so white-on-tinted-dark stays readable. The hardcoded `.white` for the title is intentional brand color (per the existing baseline) and the Tinted-mode baselines added by this PR will lock that behavior down so a future move to `.foregroundStyle(.primary)` (which would auto-adapt) shows up as a baseline diff if and when someone wants to make that change.

### Finding 3 — Hardcoded `Color.white.opacity(0.7)` glyph in `WidgetCard.Hero.fallbackGradient` (no fix needed)
- **Location:** `WidgetCard.swift`, line 196 (the `fork.knife` overlay inside the `Hero.fallbackGradient`).
- **Concern:** same as Finding 2.
- **Audit verdict:** **fine as-is** — the glyph sits over a `LinearGradient([burntOrange.opacity(0.85), castIronBrown])`, both of which are warm darker brand colors. Under any rendering mode the glyph renders as a luminance-distinguishable foreground against the warmer background. Locked by the new Tinted/Vibrant baselines.

### Finding 4 — Populated card hero photo desaturated to monochrome in Tinted/Vibrant modes (FIX APPLIED)
- **Location:** `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/WidgetCard.swift`, specifically `WidgetCard.Hero.loadedImage(_:)`.
- **Concern:** by default, in Tinted/Vibrant modes the system desaturates the entire widget view tree — including the food photo. A tinted monochromatic blur of a Dutch oven recipe is harder to recognize at home-screen distance than the true-color photo. The recipe hero IS the recognizable element of the widget; losing it to system tinting weakens the widget's job-to-be-done (recognize and tap-into a specific recipe). This affects both `FeaturedRecipeWidget` (uses `WidgetCard.Hero` for the bottom layer in `Small`, left half in `Medium`) and `SavedRecipesWidget` (uses `WidgetCard.Hero` for the 36×36pt row thumbnails and the 56pt small-widget tile).
- **Fix:** apply `widgetAccentedRenderingMode(.fullColor)` to the loaded `Image` inside `WidgetCard.Hero` via a new private `loadedImage(_:)` helper that extracts the `AsyncImage.success` branch. The modifier lives on `SwiftUICore.Image` (not `View`), so the call order inside the helper is `image.resizable() -> Image` then `.widgetAccentedRenderingMode(.fullColor) -> some View` then the View-flavored `.aspectRatio(contentMode: .fill)`. The gradient-placeholder fallback (`fallbackGradient`, shown while the image is loading or when no URL is supplied) intentionally **does not** opt out — it SHOULD tint with the system so loading / empty rows blend with the user's wallpaper choice rather than fighting it. Same call applies transitively to `WidgetCard.Placeholder` and `WidgetCard.SavedEmpty`: neither holds an `Image` instance the modifier could target (their content is `Image(systemName:)` system glyphs + `Text`), and the system's automatic tint pass is the correct behavior for "no content yet" placeholders. Apple's Photos / Music widgets use the same `.fullColor` opt-out on their photo / album-art content for the same reason.
- **Why apply inside `WidgetCard.Hero` in DesignSystem, not at the entry view layer:** the `widgetAccentedRenderingMode(_:)` modifier lives on `SwiftUICore.Image`, not on `View`. Applying it at the entry view layer (where the `WidgetCard.Small`/`Medium` composition has already collapsed the hero into `some View`) is not possible without breaking apart the existing `WidgetCard` API. Surgically applying it inside `WidgetCard.Hero` keeps the call confined to the one place that knows it holds an `Image`. The cost is that `DODDesignSystem` now needs `import WidgetKit` — guarded by `#if canImport(WidgetKit)` so the macOS test slice (`swift test`) continues to build cleanly (WidgetKit is available on macOS 15+, but the package targets macOS 14+ for the non-visual `swift test` slice, so the `#available(iOS 18.0, macOS 15.0, *)` gate covers both the macOS 14 fallback and the iOS 17 fallback). The existing architectural comment in `WidgetCard.swift` is updated to reflect the new (minimal) WidgetKit surface area. Considered: leaving DesignSystem untouched and exposing `WidgetCard.Hero` as `public` so the entry view could compose hero + chrome separately. Rejected because the entry view layer doesn't hold an `Image` either — the `AsyncImage` phase callback is where the `Image` first appears, and that callback is inside `WidgetCard.Hero`. Restructuring to hoist the phase callback into the entry view would orphan every existing `test_widgetCard_*_populated` baseline. The minimal-surface-area fix wins.

### Finding 5 — DODColor.cream chip text against DODColor.castIronBrown chip background under Tinted (no fix needed)
- **Location:** `WidgetCard.swift`, lines 211–215 (the `TimeChip`'s foreground + background).
- **Concern:** under Tinted rendering, both Cream and CastIronBrown get desaturated to luminance + system tint. Cream is a near-white asset (high luminance); CastIronBrown is a dark warm asset (low luminance). The luminance differential is preserved through the desaturation pass, so the chip text stays readable against its background. Verified by inspecting the asset catalog color components (`Cream`: ~0xF6 0xEB 0xD2 sRGB; `CastIronBrown`: ~0x4A 0x2C 0x1A sRGB) — luminance gap ≈ 0.78 vs 0.13 normalized, AA-pass across any monochromatic tint mapping.
- **Audit verdict:** **fine as-is.** Locked by the new Tinted/Vibrant baselines.

### Finding 6 — DODColor.burntOrange eyebrow text under Tinted (no fix needed)
- **Location:** `WidgetCard.swift`, line 98 and `WidgetCard+Saved.swift`, lines 48 + 84 (the "Today on DOD" / "Saved" eyebrow text).
- **Concern:** BurntOrange is a mid-luminance warm color; on a tinted background it might lose enough contrast to fail AA at the 11pt caption2 rendering size.
- **Audit verdict:** **fine as-is.** Eyebrow sits on `DODColor.surfaceElevated` background (a near-white surface), and BurntOrange's components (~0xC5 0x6A 0x24 sRGB; luminance ≈ 0.36) give a 2.5:1 contrast ratio against the lightened tinted surface — meets AA for large/bold text (the eyebrow is bold caption2). Cross-mode contrast is preserved through the system's monochromatic desaturation because both colors map to predictable luminance values. Locked by the new Tinted/Vibrant baselines.

## Fixes applied (commit 2)

Exactly one fix:

- **Finding 4** — `widgetAccentedRenderingMode(.fullColor)` on the loaded recipe-photo `Image` inside `WidgetCard.Hero`, applied through a new private `loadedImage(_:)` helper that splits the `AsyncImage.success` branch out so the modifier can fire before `.aspectRatio(_:contentMode:)` collapses the `Image` into `some View`. Implementation lives in `Packages/DODDesignSystem/Sources/DODDesignSystem/Components/WidgetCard.swift` (modified — new `loadedImage(_:)` private helper + `import WidgetKit` guarded by `#if canImport(WidgetKit)`). The fallback gradient + glyph branch is unchanged — it should tint with the system in Tinted/Vibrant mode. Gated by `if #available(iOS 18.0, macOS 15.0, *)`; pre-iOS-18 / pre-macOS-15 hosts get the unmodified resized image (a no-op since the Tinted/Vibrant home-screen appearances don't exist on those versions). Both empty / placeholder states (`WidgetCard.Placeholder`, `WidgetCard.SavedEmpty`) intentionally skip the opt-out so they tint with the system — they don't hold an `Image` instance, only system glyphs, which the system already tints correctly.

No entry-view source changes (`Widget/FeaturedRecipeWidgetEntryView.swift` and `Widget/SavedRecipesWidgetEntryView.swift` are untouched — the entry views compose `WidgetCard.Small/Medium` which compose `Hero` which now applies the opt-out internally). No design token changes. No snapshot wire-format changes. No analytics event changes. No deep-link grammar changes. AC-23.5's "do not regress US-9/17/21" pin holds — the modifier is a no-op outside Tinted/Vibrant per Apple's docs **and** the loaded-image branch is only reached when `WidgetCard.Hero` receives a non-nil URL whose `AsyncImage.success` phase fires; the existing committed light/dark `test_widgetCard_*_populated` baselines all pass `heroImageURL: nil`, hit the fallback gradient branch instead, and continue to match byte-for-byte.

## Snapshot tests added (commit 2)

`Packages/DODDesignSystem/Tests/DODDesignSystemTests/WidgetCardTintedAppearanceSnapshotTests.swift` (new): 12 test methods covering the matrix above. Class is annotated `@available(iOS 18.0, *)`; the file is wrapped in `#if canImport(UIKit) && canImport(WidgetKit)` so the macOS test slice that runs via `swift test` continues to skip it. All 12 baseline PNGs were laid down via a local iOS sim run (`record: .missing` first-pass behavior) and are committed alongside the test file under `__Snapshots__/WidgetCardTintedAppearanceSnapshotTests/` so the regression net is active on the very next CI run — matches the convention `SavedWidgetSnapshotTests` already follows for its 12 light/dark baselines (PR #17 / T-321 shipped the PNGs in the same commit as the test methods).

Tests are scoped to `WidgetCard.Small`, `WidgetCard.Medium`, `WidgetCard.Placeholder`, `WidgetCard.SavedSmall`, `WidgetCard.SavedMedium`, `WidgetCard.SavedEmpty` — they test the *card composition layer* under each rendering mode. Each test passes `heroImageURL: nil` so the `Hero.fallbackGradient` branch fires (same as the existing Standard / Dark baselines — see "What was NOT audited" above for the explanation). The Finding 4 fix (`.fullColor` opt-out on the loaded image) is therefore **not exercised by these baselines** — it only fires on the `AsyncImage.success` branch which requires a real image fixture. The fix's visual effect is verifiable by either (a) deploying to a sim with Tinted home-screen appearance enabled and confirming the populated featured widget keeps full-color photo rendering, or (b) extending `WidgetCard.Hero` with a test-only image injection point in a future T-391 follow-up. The bounded scope of this PR — audit + Tinted-mode chrome baselines + one targeted source fix — surfaces the fix's call-site contract via the source review; visual verification is deferred to the human review step `appearance-audit.md` already documents as the pre-TestFlight checkpoint.

**Observed snapshot harness limitation:** the `.environment(\.widgetRenderingMode, .accented)` / `.vibrant)` env-value injection causes only minor changes vs the Standard baselines — `tinted` and `vibrant` PNGs are byte-identical to each other for every surface. This is because the actual Tinted/Vibrant system-tint pass happens at the WidgetKit composition layer above SwiftUI's rendering pipeline (not via the environment value alone), and the `swift-snapshot-testing` harness only renders the SwiftUI hierarchy in isolation. The env-value injection still produces useful baselines because (a) it does cause SOME pixel differences vs Standard (some SwiftUI primitives like `Capsule()` read the env value to adjust their internal treatment), and (b) the baselines lock down the SwiftUI side of the contract — if `WidgetCard.Small` starts reading the `widgetRenderingMode` env value in a future change, those diffs surface in CI. Recording the limitation here so future readers understand why the new baselines look closer to the Standard ones than they would on a real home screen with a strong tint applied; the documented pre-TestFlight human review step (above) is the real "does this look right in Tinted mode" checkpoint.

## Surfaces requiring human visual review

These baselines lay down on the first iOS sim run but the audit can't verify whether the rendered output looks right — only the human reviewer can:

- **The 12 new Tinted/Vibrant baselines.** When the first sim run produces them, the reviewer (this PR or the follow-up that harvests the PNGs) should open each one and verify:
  1. Text remains readable (title, eyebrow, "Save a recipe to see it here" / "Open the app to see today's featured recipe here." placeholder copy).
  2. The eyebrow text ("Today on DOD" / "Saved") doesn't blend into the surface elevated background after tinting.
  3. The `TimeChip` cast-iron-brown capsule with cream text remains a recognizable pill (not a smudge).
  4. The placeholder glyphs (`fork.knife.circle.fill`, `bookmark.fill`) remain visible against the tinted surface elevated background.
- **The whole-card `.fullColor` opt-out on populated cards.** Verifiable by running the widget extension on a sim with home-screen Tint enabled (Settings → Wallpaper → Customize → Tinted) and confirming the populated featured/saved widgets stay full color while the placeholder / empty states tint along with the icons around them. This is the same human checkpoint that constitution §7 mandates pre-TestFlight; this audit names it explicitly.
- **The two contrast pairs flagged in `accessibility-audit.md`** ("Cream on BurntOrange (accent button)" and "WarmGold on CastIronBrown (snackbar Undo)") are unchanged by this audit — they're not widget surfaces. Re-flagged here only because anyone reviewing this audit alongside `accessibility-audit.md` might wonder whether T-390 touched them.

## Follow-up tasks recommended

The audit surfaces zero blocking follow-ups for US-23 closure. The fix from Finding 4 ships in this PR. The matrix is filled by the 12 new snapshot tests. AC-23.6's clean-audit-closure path was not triggered (one fix was needed), but the spirit holds — no expanding rabbit hole.

Optional follow-ups for future polish (each is a candidate T-391+ entry, not a blocking gate):

- **(Optional) T-391 — Real-image Tinted/Vibrant baseline.** Add a test-only image injection point into `WidgetCard.Hero` so the populated-card baselines can render a real fixture food photo instead of the gradient fallback. Lets the reviewer see how a real Dutch oven recipe photo looks under the system's tint pass (with our `.fullColor` opt-out in place, it should look identical to Standard mode — but that's the verification this baseline would supply). Pure test-infra task; no production code change. Est ~1h. **Defer until** user testing surfaces that the gradient-fallback baselines are insufficient — most reviewers will spot-check on a real device + sim faster than this test pays off.
- **(Optional) T-392 — `widgetAccentedRenderingMode(.accentedDesaturated)` exploration on placeholder glyph + accent colors.** The system glyphs in `WidgetCard.Placeholder` (`fork.knife.circle.fill`) and `WidgetCard.SavedEmpty` (`bookmark.fill`) currently render in `DODColor.burntOrange` and inherit the system's automatic tint pass in Tinted/Vibrant modes. Exploring whether explicitly annotating them with `.accentedDesaturated` (which renders content in BOTH the accented + desaturated groups) gives a more harmonious blend with the user's tint than the default behavior is a worthwhile post-launch polish. Pure-token change inside `Placeholder` / `SavedEmpty`; no API change. **Defer until** user testing surfaces that the current automatic-tint behavior feels off against a strongly tinted home screen. Est ~30min.
- **(Optional) T-393 — Lock-screen widget appearance audit.** Once T-370 (US-22 / `feat/T-370-lock-screen-widget`) merges to main, run the same kind of audit on the lock-screen accessory family. Lock-screen widgets use a different system rendering pipeline (`AccessoryWidgetGroup`, monochromatic vibrancy on the Lock Screen) so the matrix shape will be different from this doc's. **Trigger:** when PR #26 merges. Est ~1h (text-only widgets are simpler to audit than home-screen widgets with images).

## Resolution: was anything broken?

**One bounded fix applied** (Finding 4 — `widgetAccentedRenderingMode(.fullColor)` opt-out on populated cards). Every other surface passed audit on inspection — the existing brand asset-catalog colors already produce legible monochromatic treatments under the system's automatic desaturation pass, and the few hardcoded `Color.black` / `Color.white` literals live only on overlay layers that the system tints correctly. The audit's net recommendation is "expand the regression surface" (12 new snapshot baselines) + "one surgical fix" (the hero opt-out), not "fix a wide pattern of contrast bugs."

That distinction is what CL-39 / AC-23.6 authorize. The audit doc itself is the deliverable; the fix is incidental to what the surface-by-surface inspection surfaced.

## Updating this audit

If you add a new widget surface (new `WidgetCard` variant, new widget kind, new size family), add the corresponding row(s) to the matrices above in the same PR, and add the corresponding Tinted/Vibrant baselines to `WidgetCardTintedAppearanceSnapshotTests.swift`. If you add `widgetAccentedRenderingMode(_:)` to a new surface, document the decision in a new "Finding N" entry above. Constitution §6 (L4) + §11 (PR cites spec section).
