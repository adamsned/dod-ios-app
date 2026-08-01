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
/// DUT-1323, corrected — a first pass swapped the DUT-1322 fixed-opacity
/// black scrim for `.ultraThinMaterial` plus a `DODColor.darkEarth` tint,
/// but chased `tintOpacity` up to 0.75 to hold WCAG 3:1 for a
/// SAVED/DOWNLOADED state that tinted the glyph `DODColor.accent`/
/// `DODColor.burntOrange` (mid-luminance burnt-orange). Ned rejected that
/// chip as still too dark. The actual fix breaks the constraint instead of
/// satisfying it: SAVED/DOWNLOADED no longer tints the glyph orange at all
/// (`DODColor.cream` instead — see `ToolbarGlyphChip.swift`'s type doc for
/// the full trail), which lets `tintOpacity` drop back to a genuinely soft
/// 0.35. Full on-screen contrast (material + tint together) genuinely can't
/// be computed here — a `Material` has no fixed resolvable color outside a
/// live view hierarchy/trait environment — so it was verified empirically
/// instead (`xcrun simctl` screenshots + measured pixel colors across
/// light/dark appearance × hero photo/`Surface`, documented in
/// `ToolbarGlyphChip.swift` and the PR description).
///
/// What CAN be tested here, deterministically, is (1) the state → color
/// mapping itself, with real discriminating power against active/unset
/// collapsing to the same color, and (2) `tintOpacity` staying within the
/// bounds Ned's correction actually requires: soft enough that it doesn't
/// regress back toward the rejected 0.75, but non-trivial enough that it
/// isn't accidentally zeroed.
@Suite("Toolbar glyph chip — DUT-1322/DUT-1323 contrast fix")
struct ToolbarGlyphChipTests {

    // MARK: — ToolbarGlyphForeground: state → color mapping

    @Test
    func savedGlyphUsesCream() {
        #expect(ToolbarGlyphForeground.save(isSaved: true) == DODColor.cream)
    }

    @Test
    func unsavedGlyphUsesLabel() {
        #expect(ToolbarGlyphForeground.save(isSaved: false) == DODColor.label)
    }

    @Test
    func downloadedGlyphUsesCream() {
        #expect(ToolbarGlyphForeground.download(isDownloaded: true) == DODColor.cream)
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

    /// Explicit, direct version of the requirement the ticket calls out by
    /// name: active and unset must not read as the same color. The four
    /// mapping tests above already pin each branch to a distinct constant,
    /// so this is belt-and-suspenders — but it's the one assertion that
    /// still fails on its own even if a future edit repointed both branches
    /// at some new THIRD shared color that neither existing mapping test
    /// happens to name.
    @Test
    func savedGlyphDiffersFromUnsavedGlyph() {
        #expect(
            ToolbarGlyphForeground.save(isSaved: true)
                != ToolbarGlyphForeground.save(isSaved: false)
        )
    }

    @Test
    func downloadedGlyphDiffersFromNotDownloadedGlyph() {
        #expect(
            ToolbarGlyphForeground.download(isDownloaded: true)
                != ToolbarGlyphForeground.download(isDownloaded: false)
        )
    }

    // MARK: — Brightness step (DUT-1323 correction)

    /// With hue no longer carrying the state signal (SAVED/DOWNLOADED are no
    /// longer burnt-orange), Ned's instruction requires state to ALSO read
    /// via "a slight brightness step" on top of the filled-vs-outline SF
    /// Symbol swap. Reproduces the same WCAG relative-luminance math as the
    /// tint-floor tests below over the two glyph colors directly (no tint/
    /// material involved — this is a pure color-token comparison) and
    /// asserts the active-state color is measurably brighter, not just
    /// "different" (a broken change that picked two arbitrarily different
    /// but equally dark colors would fail this even though it would pass
    /// the not-equal checks above).
    @Test
    func creamActiveStateIsBrighterThanLabelUnsetState() {
        let creamLuminance = WCAG.relativeLuminance(
            red: Self.cream.red,
            green: Self.cream.green,
            blue: Self.cream.blue
        )
        let labelLuminance = WCAG.relativeLuminance(
            red: Self.labelDarkAppearance.red,
            green: Self.labelDarkAppearance.green,
            blue: Self.labelDarkAppearance.blue
        )
        #expect(creamLuminance > labelLuminance)
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

    // MARK: — Tint opacity bounds (DUT-1323 correction)

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

    /// This is the test the ticket calls a "tint-floor" test in the sense
    /// that matters here: Ned's instruction was explicit that if the tint
    /// ever needs to exceed ~0.5 to hold contrast, that means the styling
    /// has stopped being "genuinely soft" and the fix has failed — do NOT
    /// silently push it back up. This pins that ceiling directly, so a
    /// regression that crept `tintOpacity` back toward the rejected 0.75
    /// (e.g. someone re-adding an orange active state and "fixing" contrast
    /// the old way) fails HERE, not just via the exact-value pin below.
    @Test
    func tintOpacityStaysUnderTheSoftChipCeiling() {
        #expect(ToolbarGlyphChip.tintOpacity <= 0.5)
    }

    /// The real on-device floor (material + tint together, against BOTH
    /// `DODColor.cream` and `DODColor.label`) can't be re-derived by pure
    /// arithmetic — `.ultraThinMaterial` has no fixed resolvable color
    /// outside a live trait environment, and tint-alone arithmetic doesn't
    /// clear 3:1 at this soft an opacity for either glyph color (see
    /// `tintAloneDoesNotByItselfClearTheWCAGFloor` below — that's expected,
    /// not a bug, since the material's own un-mockable contribution is what
    /// closes the real gap, per `ToolbarGlyphChip.swift`'s empirical trail).
    /// So — same pattern the pre-correction suite used for the
    /// accent/burnt-orange case — this pins the exact empirically validated
    /// constant instead of a derived inequality: changing `tintOpacity`
    /// again requires re-running the `xcrun simctl` screenshot verification,
    /// not just satisfying this test.
    @Test
    func tintOpacityMatchesEmpiricallyValidatedValue() {
        #expect(ToolbarGlyphChip.tintOpacity == 0.35)
    }

    // MARK: — Fixed-tint arithmetic (documents what tint-alone CAN and
    // CANNOT prove, at the corrected value)

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
        /// returns.
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
            return relativeLuminance(
                red: compositedRed,
                green: compositedGreen,
                blue: compositedBlue
            )
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

    /// `DODColor.cream` — fixed hex in BOTH appearances (`Cream.colorset`
    /// only has a `universal` entry, no dark override), so it can't itself
    /// flip under any environment. Sourced from `Cream.colorset/Contents
    /// .json` (`0xFA, 0xF6, 0xEE`).
    private static let cream = (
        red: Double(0xFA) / 255, green: Double(0xF6) / 255, blue: Double(0xEE) / 255
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

    /// Documents (rather than asserts a passing floor from) a real fact
    /// about the corrected, softer tint: at `tintOpacity` 0.35, DarkEarth
    /// tint-ALONE — material contributing nothing, the most conservative
    /// possible assumption — does NOT reach 3:1 for either glyph color
    /// against the worst-case backdrop (cream ≈2.08:1, label ≈1.68:1 here).
    /// That's expected, not a regression: the pre-correction 0.75 value only
    /// cleared 3:1 tint-alone because it was darkened well past "soft" to
    /// compensate for a mid-luminance orange foreground that no longer
    /// exists. The REAL floor for the current, lighter foregrounds is
    /// necessarily a material+tint measurement, not tint-alone arithmetic —
    /// hence `tintOpacityMatchesEmpiricallyValidatedValue` pinning the
    /// screenshot-verified constant instead of deriving an inequality here.
    /// This test exists so a future reader can't mistake "tint-alone doesn't
    /// clear 3:1" for a bug — it's asserted as a documented, expected fact.
    @Test
    func tintAloneDoesNotByItselfClearTheWCAGFloorAtTheCorrectedOpacity() {
        let tintLuminance = WCAG.blendColorThenLuminance(
            red: Self.darkEarth.red,
            green: Self.darkEarth.green,
            blue: Self.darkEarth.blue,
            opacity: ToolbarGlyphChip.tintOpacity,
            overEncodedBackdrop: Self.worstCaseEncodedBackdrop
        )
        let creamLuminance = WCAG.relativeLuminance(
            red: Self.cream.red,
            green: Self.cream.green,
            blue: Self.cream.blue
        )
        let labelLuminance = WCAG.relativeLuminance(
            red: Self.labelDarkAppearance.red,
            green: Self.labelDarkAppearance.green,
            blue: Self.labelDarkAppearance.blue
        )
        #expect(WCAG.contrastRatio(tintLuminance, creamLuminance) < 3.0)
        #expect(WCAG.contrastRatio(tintLuminance, labelLuminance) < 3.0)
    }
}
