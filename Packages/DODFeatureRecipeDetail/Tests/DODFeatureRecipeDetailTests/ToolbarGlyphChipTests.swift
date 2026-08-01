import DODDesignSystem
import Foundation
import SwiftUI
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-1322/DUT-1323 — locks the toolbar-glyph contrast fix.
/// `DODFeatureRecipeDetail` has no `swift test`-reachable snapshot
/// infrastructure (the existing `RecipeDetailViewSnapshotTests` suite is
/// `#if canImport(UIKit)`-gated and only runs via an iOS-simulator
/// `xcodebuild` destination, not the package's native `swift test`), and
/// generating a NEW baseline locally can't be guaranteed to match what CI
/// renders (see the team's own recorded "L4 snapshot baseline drift"
/// recovery process for DODDesignSystem) — so this suite covers the pure,
/// environment-free surface instead: ``ToolbarGlyphForeground``'s state →
/// color mapping, and WCAG contrast checks.
///
/// DUT-1323 swapped the DUT-1322 fixed-opacity black scrim for
/// `.ultraThinMaterial` (an Apple system `Material`) plus a fixed
/// `DODColor.darkEarth` tint underneath. A `Material` has no fixed
/// resolvable color outside a live view hierarchy/trait environment, so the
/// FULL on-screen contrast (material + tint together) genuinely can't be
/// computed here — it was verified empirically instead (`xcrun simctl`
/// screenshots + measured pixel colors across light/dark appearance × hero
/// photo/`Surface`, documented in `ToolbarGlyphChip.swift` and the PR
/// description: 9.04:1–12.61:1 for the neutral cream glyph, 3.14:1–4.38:1
/// for the accent/burnt-orange saved/downloaded glyph — all clearing the
/// WCAG 1.4.11 3:1 non-text floor with margin).
///
/// What CAN be tested here, deterministically, is the FIXED tint's own
/// contribution in isolation — modeling `.ultraThinMaterial` as contributing
/// NOTHING (the most conservative assumption possible), composited over a
/// worst-case full-white backdrop. For the cream label glyph this actually
/// clears the real WCAG 3:1 floor from tint-alone arithmetic (no material
/// credit needed) — see `tintAloneClearsWCAGFloorForCreamLabelOverWorstCaseBackdrop`.
/// For the accent/burnt-orange glyph it does NOT (that color's luminance
/// sits close enough to a lightly-tinted chip's own luminance that
/// tint-alone contrast is non-monotonic in opacity and never a clean win at
/// the softer opacity this PR shipped) — so that case is guarded by pinning
/// the exact empirically validated constant instead; see
/// `tintOpacityMatchesEmpiricallyValidatedValue` for the full reasoning.
@Suite("Toolbar glyph chip — DUT-1322/DUT-1323 contrast fix")
struct ToolbarGlyphChipTests {

    // MARK: — ToolbarGlyphForeground: state → color mapping

    @Test
    func savedGlyphUsesAccent() {
        #expect(ToolbarGlyphForeground.save(isSaved: true) == DODColor.accent)
    }

    @Test
    func unsavedGlyphUsesLabel() {
        #expect(ToolbarGlyphForeground.save(isSaved: false) == DODColor.label)
    }

    @Test
    func downloadedGlyphUsesBurntOrange() {
        #expect(ToolbarGlyphForeground.download(isDownloaded: true) == DODColor.burntOrange)
    }

    @Test
    func notDownloadedGlyphUsesLabel() {
        #expect(ToolbarGlyphForeground.download(isDownloaded: false) == DODColor.label)
    }

    @Test
    func neutralGlyphUsesLabel() {
        // Add to Shopping List + Share — neither carries a toggle state.
        #expect(ToolbarGlyphForeground.neutral == DODColor.label)
    }

    // MARK: — ToolbarGlyphChip: tap target isn't shrunk

    /// The pre-fix glyphs had no explicit frame (their footprint was just the
    /// bare SF Symbol's intrinsic size, well under 34pt). Asserting the real
    /// production constant stays at/above that floor guards against a future
    /// edit quietly shrinking the chip back down.
    @Test
    func chipDiameterDoesNotShrinkBelowPreFixGlyphSize() {
        #expect(ToolbarGlyphChip.diameter >= 34)
    }

    // MARK: — Tint opacity sanity (DUT-1323)

    /// `tintOpacity` must be a REAL, non-trivial fixed tint — not
    /// accidentally zeroed (which would revert to bare `.ultraThinMaterial`,
    /// measured to fail WCAG 3:1 on its own — see `ToolbarGlyphChip.swift`)
    /// and not `>= 1` (which would make ``DODColor/darkEarth`` fully opaque,
    /// defeating the whole "translucent glass, not a flat dot" point of
    /// keeping `.ultraThinMaterial` in the stack at all).
    @Test
    func tintOpacityIsWithinExclusiveBounds() {
        #expect(ToolbarGlyphChip.tintOpacity > 0)
        #expect(ToolbarGlyphChip.tintOpacity < 1)
    }

    // MARK: — Fixed-tint contrast floor (DUT-1323)

    /// Reproduces WCAG relative-luminance / contrast-ratio math over plain
    /// sRGB triples — deliberately NOT going through `Color`/`UIColor`
    /// resolution, which needs a live trait environment for asset-catalog
    /// colors and would make this test depend on the runner's rendering
    /// environment rather than pure arithmetic.
    private enum WCAG {
        static func linearize(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }

        static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
            0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
        }

        static func contrastRatio(_ l1: Double, _ l2: Double) -> Double {
            let lighter = max(l1, l2) + 0.05
            let darker = min(l1, l2) + 0.05
            return lighter / darker
        }

        /// A `red`/`green`/`blue` color at `opacity` composited over an
        /// opaque backdrop — alpha-blended in gamma-ENCODED sRGB space (how
        /// on-screen compositing actually happens), matching what a real
        /// device renders. Linearizing an already-linear luminance and
        /// scaling THAT by `(1 - opacity)` would understate how dark the
        /// composite gets, since gamma linearization is non-linear
        /// (`pow(_, 2.4)`) — blending the encoded components first, THEN
        /// linearizing the composite, is the correct order and is what this
        /// returns. Generalizes DUT-1322's `blendBlackThenLuminance` (which
        /// only had to model pure black, where every channel contributes 0)
        /// to an arbitrary fixed tint color.
        static func blendColorThenLuminance(
            red: Double,
            green: Double,
            blue: Double,
            opacity: Double,
            overEncodedBackdrop backdrop: Double
        ) -> Double {
            let compositedRed = backdrop * (1 - opacity) + red * opacity
            let compositedGreen = backdrop * (1 - opacity) + green * opacity
            let compositedBlue = backdrop * (1 - opacity) + blue * opacity
            return relativeLuminance(red: compositedRed, green: compositedGreen, blue: compositedBlue)
        }
    }

    /// `DODColor.label`'s dark-appearance value — the one it ALWAYS resolves
    /// to on the recipe-detail toolbar, since `RecipeDetailView` forces
    /// `.toolbarColorScheme(.dark, for: .navigationBar)` (DUT-572 / CL-312).
    /// Sourced from `DODDesignSystem/Resources/Colors.xcassets/Label
    /// .colorset/Contents.json`'s dark-appearance entry (`0xE6, 0xDE, 0xCF`).
    private static let labelDarkAppearance = (
        red: Double(0xE6) / 255, green: Double(0xDE) / 255, blue: Double(0xCF) / 255
    )

    /// ``DODColor/darkEarth`` — the DUT-1323 supplementary tint color, fixed
    /// hex in BOTH appearances. Sourced from `DarkEarth.colorset` (`0x1B,
    /// 0x14, 0x0E`).
    private static let darkEarth = (
        red: Double(0x1B) / 255, green: Double(0x14) / 255, blue: Double(0x0E) / 255
    )

    /// Worst-case realistic backdrop the chip has to survive: a bright hero
    /// highlight, or the light-mode `DODColor.surface` (`#FFFFFF`) once
    /// scrolled past the hero — both ≈ full white, encoded value `1.0`. A
    /// darker backdrop (dark mode `Surface`, a dim hero region) can only
    /// improve contrast, so this is the number that matters.
    private static let worstCaseEncodedBackdrop = 1.0

    /// Unlike DUT-1322's pure-black scrim, `DODColor.darkEarth` at
    /// `tintOpacity` composited alone (material contributing nothing) is
    /// NOT monotonic in opacity against a FIXED foreground: as opacity rises
    /// from 0, the composite's luminance falls from white (1.0) toward
    /// `darkEarth`'s own near-black luminance, so contrast against any FIXED
    /// foreground dips to a minimum right where the two luminances cross,
    /// then recovers as the composite keeps getting darker. For the cream
    /// label (`relativeLuminance` ≈0.736, high), that crossing/minimum
    /// happens at LOW opacity (≈0.15) and 3:1 is only reached once opacity
    /// rises past ≈0.53 and stays cleared all the way to `tintOpacity`'s
    /// actual 0.75 (≈6.07:1 tint-alone here) — a single, clean, high-margin
    /// crossing in the direction that matters (weakening the tint below
    /// ≈0.53 fails this; the current value passes with room). This is a
    /// REAL, non-vacuous WCAG 1.4.11 floor for the label glyph — verified
    /// tint-ALONE, not relying on `.ultraThinMaterial`'s un-mockable
    /// contribution at all (which only makes the real on-device number
    /// better, per the empirically-measured 9.04:1–12.61:1 in
    /// `ToolbarGlyphChip.swift`'s type doc).
    @Test
    func tintAloneClearsWCAGFloorForCreamLabelOverWorstCaseBackdrop() {
        let tintLuminance = WCAG.blendColorThenLuminance(
            red: Self.darkEarth.red,
            green: Self.darkEarth.green,
            blue: Self.darkEarth.blue,
            opacity: ToolbarGlyphChip.tintOpacity,
            overEncodedBackdrop: Self.worstCaseEncodedBackdrop
        )
        let labelLuminance = WCAG.relativeLuminance(
            red: Self.labelDarkAppearance.red,
            green: Self.labelDarkAppearance.green,
            blue: Self.labelDarkAppearance.blue
        )
        let contrast = WCAG.contrastRatio(tintLuminance, labelLuminance)
        #expect(contrast >= 3.0)
    }

    /// The SAME non-monotonic crossing described above happens for
    /// `DODColor.accent`/`burntOrange` (`relativeLuminance` ≈0.223, much
    /// lower than the label's) — but its crossing/minimum sits at a much
    /// HIGHER opacity (≈0.53), and the tint alone does NOT climb back over
    /// 3:1 until roughly 0.84, well past `tintOpacity`'s actual 0.75
    /// (≈2.11:1 tint-alone there). So — UNLIKE the label case above — the
    /// accent/burntOrange 3:1 floor genuinely cannot be proven from
    /// tint-alone arithmetic at the softer opacity this PR shipped; only
    /// `.ultraThinMaterial`'s real, un-mockable contribution closes that
    /// last gap (measured 3.14:1–4.38:1 on-device — see
    /// `ToolbarGlyphChip.swift`). This was the actual failure DUT-1323's
    /// verification caught: at the first, lighter `tintOpacity` guess
    /// (0.35), this color's REAL on-device contrast measured only 1.71:1 —
    /// a near-miss the label case alone would NOT have caught (its own
    /// tint-alone number, ≈1.68:1 at that same 0.35, looks similarly weak,
    /// but a reviewer eyeballing "the neutral glyph looks fine" screenshots
    /// could easily have missed testing the SAVED state at all). Because the
    /// real floor here depends on `.ultraThinMaterial` and can't be
    /// re-derived by arithmetic, this test pins the exact empirically
    /// validated constant instead of a derived inequality — a deliberate
    /// choice: changing `tintOpacity` again requires re-running the
    /// `xcrun simctl` screenshot verification in `ToolbarGlyphChip.swift`'s
    /// type doc, not just satisfying this test.
    @Test
    func tintOpacityMatchesEmpiricallyValidatedValue() {
        #expect(ToolbarGlyphChip.tintOpacity == 0.75)
    }
}
