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

/// A circular translucent scrim behind a single recipe-detail toolbar glyph,
/// applied via `View.toolbarGlyphChip(foreground:)` below.
///
/// The scrim is a FIXED-opacity black circle — deliberately NOT a
/// `Material` and NOT a color that adapts to the real (device) color scheme.
/// `RecipeDetailView` already forces `.toolbarColorScheme(.dark, for:
/// .navigationBar)`, so every glyph's own foreground is ALREADY pinned to
/// its dark-appearance token regardless of the device's actual appearance
/// (see the file-level doc above). Given that, the scrim only needs to
/// guarantee contrast against whatever page content happens to sit behind
/// it — it doesn't need to adapt to anything itself.
///
/// Contrast math (WCAG relative luminance, worst realistic backdrop = a
/// bright hero highlight or the light-mode white `Surface`, both ≈ full
/// white):
/// - `DODColor.label`'s dark-appearance cream (`#E6DECF`, relative luminance
///   ≈0.75) against the scrim (`#000000` at `scrimOpacity` composited over
///   white ⇒ ≈`#363636`, relative luminance ≈0.033) ⇒ contrast ≈9.5:1.
/// - `DODColor.accent` / `DODColor.burntOrange` (both `#C56A24` — the two
///   tokens currently share this hex — relative luminance ≈0.23) against the
///   same scrim ⇒ contrast ≈3.9:1.
///
/// Both numbers only IMPROVE over a darker backdrop (a dim hero region, or
/// the dark-mode near-black `Surface`), so one fixed scrim covers light
/// mode, dark mode, over-the-hero, and scrolled-past-the-hero without any
/// environment branching. 3:1 is the WCAG 1.4.11 non-text-contrast floor for
/// UI/graphical objects; both cases clear it with margin.
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

    /// Fixed (non-adaptive) scrim opacity. See the contrast math in the type
    /// doc above for why this specific value clears WCAG 1.4.11 for every
    /// foreground token the four glyphs can render. `nonisolated` — see
    /// ``diameter``.
    nonisolated static let scrimOpacity: Double = 0.85

    let foreground: Color

    func body(content: Content) -> some View {
        content
            .foregroundStyle(foreground)
            .frame(width: Self.diameter, height: Self.diameter)
            .background(Circle().fill(Color.black.opacity(Self.scrimOpacity)))
    }
}

extension View {
    /// Applies the DUT-1322 toolbar glyph contrast scrim: the glyph's
    /// resolved `foreground` tint over a fixed circular scrim. See
    /// ``ToolbarGlyphChip`` for why the scrim is a fixed opacity rather than
    /// an adaptive `Material`.
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
