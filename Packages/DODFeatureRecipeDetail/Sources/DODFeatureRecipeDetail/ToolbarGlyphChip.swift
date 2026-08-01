import DODDesignSystem
import SwiftUI

// DUT-1322 — the four recipe-detail toolbar glyphs (Save / Add to Shopping
// List / Download / Share) went near-invisible on iPadOS 17.7.11 once the
// page was scrolled past the hero photo.
//
// Root cause: `RecipeDetailView` hides the nav-bar background AND forces
// `.toolbarColorScheme(.dark, for: .navigationBar)` (DUT-572 / CL-312) so the
// glyphs render light OVER the full-bleed hero photo. That forcing makes
// `DODColor.label` always resolve its DARK-appearance value — cream
// `#E6DECF` — regardless of the device's real light/dark setting. Cream over
// a photo is fine; cream over the (also cream-toned) `DODColor.surface` once
// scrolled past the hero is not. iOS 26's scroll-edge nav-bar treatment
// mostly hides this; iPadOS 17's fully transparent nav bar does not — and
// iOS 17 is the package's min deployment target (`DODDesignSystem/Package
// .swift`), so this is a supported shipping configuration, not a legacy
// corner case.
//
// Fix: give each glyph its own circular translucent scrim so it reads
// against ANY backdrop (hero photo, light-mode white `Surface`, dark-mode
// near-black `Surface`) rather than trying to keep the glyph color and the
// page background from ever colliding.
//
// DUT-1323 — DUT-1322 shipped that scrim as a FIXED `Color.black.opacity
// (0.85)` circle. Ned's on-device read: legible, but "very aggressive with
// the dark fill" — four heavy dark dots sitting on the hero photo, and off
// the app's own house style for photo-legibility (`WidgetCard+Scrim.swift`
// uses a soft gradient, not a hard fill) and for toolbar glyphs
// (`DODHeaderGearButton` is a bare tinted glyph, no chip at all). This pass
// swaps the fixed fill for `.ultraThinMaterial` — the Apple-native
// translucent-blur treatment for controls over imagery (Photos, Maps) — plus
// a documented, minimal supplementary tint (see ``tintOpacity``).
//
// The DUT-1322 author deliberately rejected `Material` on the theory that,
// under the forced-dark toolbar, it might resolve its LIGHT variant and
// destroy the contrast it exists to provide. That theory was verified
// EMPIRICALLY here, not assumed: built + ran on an iPhone 16 / iOS 26.5
// simulator, navigated to a real recipe detail, and captured
// `xcrun simctl io <udid> screenshot` over the hero photo AND scrolled to
// plain `DODColor.surface`, in both light and dark device appearance
// (`xcrun simctl ui <udid> appearance light|dark`), then measured actual
// on-screen pixel colors (not theoretical ones) at the glyph and at the chip
// fill and ran the same WCAG relative-luminance / contrast-ratio math
// `ToolbarGlyphChipTests.swift` already used for the DUT-1322 scrim.
//
// Two real findings came out of that, not the guess either engineer started
// with:
//
// 1. `.ultraThinMaterial` DOES track the device's real light/dark appearance
//    (not the `.toolbarColorScheme(.dark, ...)` forced on the toolbar) — the
//    DUT-1322 author's instinct was directionally right. Measured chip-fill
//    luminance was visibly lighter in light-mode screenshots than dark-mode
//    ones at the same tint opacity. But it does NOT go fully light/see
//    through the way pure "no scrim at all" would — it still contributes
//    real, substantial darkening even in light mode.
// 2. `.ultraThinMaterial` ALONE (no supplementary tint) measured BELOW the
//    WCAG 1.4.11 3:1 non-text floor for the cream `DODColor.label` glyph in
//    light mode: 2.76:1 over the hero photo, 2.11:1 over light-mode
//    `Surface` (`#FFFFFF`). Dark mode cleared it easily (5.89:1 / 9.25:1),
//    consistent with finding 1. So a supplementary tint is required — Ned's
//    fallback instruction, not a fixed guess.
//
// The supplementary tint is `DODColor.darkEarth` (fixed hex — `#1B140E` in
// BOTH appearances, see `DODDesignSystem/Colors.swift` — so it can't itself
// flip light under any environment) at ``tintOpacity``, layered UNDER the
// material so the material's own blur + backdrop-dependent sheen still shows
// through on top of it (this is what keeps the chip reading as translucent
// glass rather than a flat matte dot — compare the visible color/light
// variation inside the chips in the screenshots this PR attaches to the flat
// single-tone circles DUT-1322 shipped).
//
// `tintOpacity` had to go through THREE empirically-measured iterations, not
// one: 0.35 was the first guess (softest option) and it held the 3:1 floor
// for `DODColor.label` in every combination (4.89:1 hero / 3.97:1 surface,
// light mode; 8.20:1 / 10.77:1 dark mode) — but a state this suite hadn't
// screenshotted yet, the SAVED bookmark rendering `DODColor.accent`
// (`#C56A24`, a mid-luminance color, unlike the very-light cream label),
// measured only 1.71:1 in light mode over the hero — a real, missed failure
// a "just check the unsaved state" pass would have shipped. `DODColor.accent`
// / `DODColor.burntOrange` are close enough in luminance to a lightly-tinted
// chip that darkening the chip FURTHER (not lighter) is what closes that gap
// — a middling 0.55 only reached 2.40:1, 0.70 only 3.12:1 (too thin a
// margin), and 0.75 is the value that cleared 3:1 for the accent/burntOrange
// case with real margin in every measured combination: light-mode hero
// 3.40:1, light-mode surface 3.14:1, dark-mode hero 4.02:1, dark-mode
// surface 4.38:1 (the cream-label case clears comfortably throughout, from
// 9.04:1 up to 12.61:1).
struct ToolbarGlyphChip: ViewModifier {

    /// Circle diameter. Comfortably larger than the ~20–22pt rendered SF
    /// Symbol so the scrim reads as a chip, not a tight halo behind the
    /// glyph. The toolbar `Button` still owns the actual hit-testable area
    /// — SwiftUI sizes a custom toolbar-item button from its label's layout
    /// size — so raising this only grows the tap target, never shrinks it
    /// below what the bare (un-chipped) glyph offered before this fix.
    ///
    /// `nonisolated` — plain, immutable, `Sendable` data with no ties to the
    /// view lifecycle. Without it, `ViewModifier` conformance infers
    /// `@MainActor` isolation onto every member (including these
    /// constants), which the unit tests in `ToolbarGlyphChipTests.swift`
    /// read from a plain (non-actor-isolated) `@Test` function.
    nonisolated static let diameter: CGFloat = 34

    /// Fixed (non-adaptive) supplementary tint opacity for ``DODColor/darkEarth``,
    /// layered UNDER `.ultraThinMaterial` so the material's own blur/sheen
    /// still shows on top of it. See the type doc above for the three rounds
    /// of empirical (screenshot + measured-pixel) verification behind this
    /// exact value — 0.35 held the WCAG 1.4.11 3:1 floor for the neutral
    /// cream glyph but NOT for the accent/burnt-orange saved/downloaded
    /// glyph (1.71:1 in the worst measured case); 0.75 is the first value
    /// that cleared 3:1 for BOTH in every measured light/dark ×
    /// hero-photo/`Surface` combination. `nonisolated` — see ``diameter``.
    nonisolated static let tintOpacity: Double = 0.75

    let foreground: Color

    func body(content: Content) -> some View {
        content
            .foregroundStyle(foreground)
            .frame(width: Self.diameter, height: Self.diameter)
            .background(
                Circle()
                    .fill(DODColor.darkEarth.opacity(Self.tintOpacity))
                    .background(.ultraThinMaterial, in: Circle())
            )
    }
}

extension View {
    /// Applies the DUT-1322/DUT-1323 toolbar glyph contrast chip: the
    /// glyph's resolved `foreground` tint over a translucent
    /// `.ultraThinMaterial` circle with a fixed supplementary tint
    /// underneath. See ``ToolbarGlyphChip`` for the empirical verification
    /// behind this combination.
    func toolbarGlyphChip(foreground: Color) -> some View {
        modifier(ToolbarGlyphChip(foreground: foreground))
    }
}

/// Resolves the on-scrim foreground color for a recipe-detail toolbar glyph,
/// per glyph state. Factored out of `RecipeDetailView+Toolbar.swift` as
/// plain, environment-free data (no `View`) so the state → color mapping —
/// the "state colors must stay visually distinct" half of the DUT-1322 fix
/// — is unit-testable without a live view hierarchy.
enum ToolbarGlyphForeground {

    /// Add to Shopping List + Share — neither carries a toggle state.
    static let neutral: Color = DODColor.label

    /// Save / bookmark glyph. Saved renders `DODColor.accent` (unchanged
    /// from pre-DUT-1322 behavior); unsaved renders `DODColor.label`.
    static func save(isSaved: Bool) -> Color {
        isSaved ? DODColor.accent : DODColor.label
    }

    /// Download glyph. Downloaded renders `DODColor.burntOrange`
    /// (unchanged); not-downloaded renders `DODColor.label`.
    static func download(isDownloaded: Bool) -> Color {
        isDownloaded ? DODColor.burntOrange : DODColor.label
    }
}
