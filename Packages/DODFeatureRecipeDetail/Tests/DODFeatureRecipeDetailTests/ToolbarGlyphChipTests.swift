import DODDesignSystem
import Foundation
import SwiftUI
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-1322 — locks the toolbar-glyph contrast fix. `DODFeatureRecipeDetail`
/// has no `swift test`-reachable snapshot infrastructure (the existing
/// `RecipeDetailViewSnapshotTests` suite is `#if canImport(UIKit)`-gated and
/// only runs via an iOS-simulator `xcodebuild` destination, not the package's
/// native `swift test`), and generating a NEW baseline locally can't be
/// guaranteed to match what CI renders (see the team's own recorded
/// "L4 snapshot baseline drift" recovery process for DODDesignSystem) — so
/// this suite covers the pure, environment-free surface instead:
/// ``ToolbarGlyphForeground``'s state → color mapping, and a WCAG contrast
/// check against the REAL `ToolbarGlyphChip.scrimOpacity` constant the
/// production view code applies. Pixel-level coverage of the actual scrolled
/// toolbar was deliberately not added — see the PR description.
@Suite("Toolbar glyph chip — DUT-1322 contrast fix")
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

    // MARK: — Scrim contrast (WCAG 1.4.11 non-text contrast, floor 3:1)

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

        /// `Color.black.opacity(opacity)` composited over an opaque backdrop —
        /// alpha-blended in gamma-ENCODED sRGB space (how on-screen
        /// compositing actually happens), matching what a real device
        /// renders. Linearizing an already-linear luminance and scaling THAT
        /// by `(1 - opacity)` would understate how dark the composite gets,
        /// since gamma linearization is non-linear (`pow(_, 2.4)`) — a
        /// naive linear-luminance blend was tried first here and produced a
        /// contrast ratio that didn't match a manual reference calculation;
        /// blending the encoded components first, THEN linearizing the
        /// composite, is the correct order and is what this returns.
        static func blendBlackThenLuminance(opacity: Double, overEncodedBackdrop backdrop: Double) -> Double {
            // A pure black overlay contributes 0 to every channel, so the
            // composited ENCODED value is just the backdrop scaled down —
            // no per-channel math needed since the backdrop here is
            // achromatic (worst case: white `Surface` / a bright hero
            // highlight, r == g == b).
            let composited = backdrop * (1 - opacity)
            return relativeLuminance(red: composited, green: composited, blue: composited)
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

    /// `DODColor.accent` / `DODColor.burntOrange` — both tokens currently
    /// share this hex in BOTH appearances. Sourced from `Accent.colorset` /
    /// `BurntOrange.colorset` (`0xC5, 0x6A, 0x24`).
    private static let accentAndBurntOrange = (
        red: Double(0xC5) / 255, green: Double(0x6A) / 255, blue: Double(0x24) / 255
    )

    /// Worst-case realistic backdrop the scrim has to survive: a bright hero
    /// highlight, or the light-mode `DODColor.surface` (`#FFFFFF`) once
    /// scrolled past the hero — both ≈ full white, encoded value `1.0`. A
    /// darker backdrop (dark mode `Surface`, a dim hero region) can only
    /// improve contrast, so this is the number that matters.
    private static let worstCaseEncodedBackdrop = 1.0

    @Test
    func scrimGivesSufficientContrastForCreamLabelOverWorstCaseBackdrop() {
        let scrimLuminance = WCAG.blendBlackThenLuminance(
            opacity: ToolbarGlyphChip.scrimOpacity,
            overEncodedBackdrop: Self.worstCaseEncodedBackdrop
        )
        let labelLuminance = WCAG.relativeLuminance(
            red: Self.labelDarkAppearance.red,
            green: Self.labelDarkAppearance.green,
            blue: Self.labelDarkAppearance.blue
        )
        let contrast = WCAG.contrastRatio(scrimLuminance, labelLuminance)
        #expect(contrast >= 3.0)
    }

    @Test
    func scrimGivesSufficientContrastForAccentAndBurntOrangeOverWorstCaseBackdrop() {
        let scrimLuminance = WCAG.blendBlackThenLuminance(
            opacity: ToolbarGlyphChip.scrimOpacity,
            overEncodedBackdrop: Self.worstCaseEncodedBackdrop
        )
        let glyphLuminance = WCAG.relativeLuminance(
            red: Self.accentAndBurntOrange.red,
            green: Self.accentAndBurntOrange.green,
            blue: Self.accentAndBurntOrange.blue
        )
        let contrast = WCAG.contrastRatio(scrimLuminance, glyphLuminance)
        #expect(contrast >= 3.0)
    }
}
