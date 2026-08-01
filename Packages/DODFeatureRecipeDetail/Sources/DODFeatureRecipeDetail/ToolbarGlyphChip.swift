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
// (`DODHeaderGearButton` is a bare tinted glyph, no chip at all). A first
// pass swapped the fixed fill for `.ultraThinMaterial` — the Apple-native
// translucent-blur treatment for controls over imagery (Photos, Maps) — plus
// a `DODColor.darkEarth` tint underneath. That pass verified, empirically
// (built + ran on an iPhone 16 / iOS 26.5 simulator, navigated to a real
// recipe detail, captured `xcrun simctl io <udid> screenshot` over the hero
// photo AND scrolled to plain `DODColor.surface`, in both light and dark
// device appearance, then measured actual pixel colors and ran WCAG
// relative-luminance / contrast-ratio math), that `.ultraThinMaterial` alone
// falls below the WCAG 1.4.11 3:1 non-text floor (2.76:1 hero / 2.11:1
// surface, light mode) — so SOME supplementary tint is genuinely required,
// not a fixed guess. But it then chased `tintOpacity` up to 0.75 to hold 3:1
// for the SAVED/DOWNLOADED state, which at the time rendered
// `DODColor.accent`/`DODColor.burntOrange` (`#C56A24`, mid-luminance
// burnt-orange) directly on the chip. Reconstructed composite chip color at
// that tint: RGB (59, 54, 49) over `DODColor.surface` — warmer than the
// rejected black scrim, but still a dark dot four times over. Ned rejected
// that outcome too, for the same reason as the original: chasing 3:1 for a
// mid-luminance orange on a soft chip is exactly what forces the tint back
// up.
//
// The actual fix breaks the constraint instead of satisfying it: no
// mid-luminance brand token clears 3:1 on a genuinely soft chip —
// `DODColor.warmGold` (`#D4A24C`) reaches only 2.26:1, `DODColor.accent` /
// `DODColor.burntOrange` (`#C56A24`) only 1.36:1, both computed the same
// tint-alone way as ``ToolbarGlyphChipTests``'s floor tests. Only a
// near-white token does — `DODColor.cream` (`#FAF6EE`), ~4.85:1+ tint-alone
// at any opacity that also clears it for `DODColor.label`. So the
// SAVED/DOWNLOADED state no longer tints the glyph burnt orange at all —
// see `ToolbarGlyphForeground` below. State is carried by the
// filled-vs-outline SF Symbol variant (already wired in
// `RecipeDetailView+Toolbar.swift`: `bookmark`/`bookmark.fill`,
// `square.and.arrow.down`/`square.and.arrow.down.fill`) — the standard iOS
// idiom — plus a brightness step: `DODColor.cream` reads visibly lighter
// than `DODColor.label`'s toolbar-forced-dark value (`#E6DECF`), not a hue
// change.
//
// Dropping orange from the toolbar is what buys back the soft chip: with
// both possible glyph foregrounds now light (cream/label, not orange),
// `tintOpacity` drops from 0.75 back down to a genuinely soft 0.35 — see
// ``tintOpacity`` for the full empirical trail and the on-device
// verification screenshots this PR attaches.
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
    /// still shows on top of it. Ned's explicit correction (see the type doc
    /// above): once the SAVED/DOWNLOADED state stopped tinting the glyph
    /// burnt orange (``ToolbarGlyphForeground``), both possible glyph
    /// foregrounds are light (`DODColor.cream` / `DODColor.label`), so the
    /// tint no longer has to be darkened just to hold contrast for a
    /// mid-luminance orange — it can go back to the genuinely soft value:
    /// ~RGB 110 composited over `DODColor.surface`, clearly lighter than
    /// either the rejected `Color.black.opacity(0.85)` scrim (RGB (36, 36,
    /// 35)) or the previous `.darkEarth` tint this PR is correcting away
    /// from (0.75 → RGB (59, 54, 49)). Verified empirically (screenshots +
    /// measured pixel WCAG contrast) that both `DODColor.cream` and
    /// `DODColor.label` still clear the 1.4.11 3:1 non-text floor against
    /// this chip in every light/dark × hero-photo/`Surface` combination —
    /// see the type doc's verification trail for the measured numbers.
    /// Changing this value again requires re-running that `xcrun simctl`
    /// screenshot verification, not just satisfying
    /// `ToolbarGlyphChipTests.swift`. `nonisolated` — see ``diameter``.
    nonisolated static let tintOpacity: Double = 0.35

    let foreground: Color

    func body(content: Content) -> some View {
        // DUT-1327 — iOS 26 groups the `.primaryAction` toolbar items in its own
        // system Liquid-Glass pill, so the per-glyph chip becomes a redundant
        // second background — four gray dots inside the pill, which reads badly
        // (Spencer, on-device). Drop the circle there and let the system pill be
        // the backdrop; a subtle shadow still separates the glyph from the hero
        // photo (matches v2's toolbar treatment).
        //
        // The DUT-1322 chip is kept ONLY on iOS 17–25, which have no system glass
        // grouping (iPadOS 17's fully transparent nav bar is exactly where the
        // bare glyph went invisible over the cream `Surface`). iOS 17 is still the
        // package's min deployment target, so that path must stay.
        if #available(iOS 26, *) {
            content
                .foregroundStyle(foreground)
                .shadow(color: .black.opacity(0.35), radius: 3)
        } else {
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
///
/// DUT-1323 (Ned's correction) — SAVED/DOWNLOADED no longer tints the glyph
/// `DODColor.accent`/`DODColor.burntOrange`. That mid-luminance orange is
/// what forced ``ToolbarGlyphChip/tintOpacity`` up to a chip dark enough that
/// Ned rejected it on device a second time; no mid-luminance brand token
/// clears WCAG 1.4.11 3:1 on a genuinely soft chip (see
/// `ToolbarGlyphChip.swift`'s type doc). Active states now render
/// `DODColor.cream` — the only token with enough headroom to clear 3:1 at a
/// soft tint — instead. State is carried primarily by the filled-vs-outline
/// SF Symbol variant already wired in `RecipeDetailView+Toolbar.swift` (the
/// standard iOS idiom), with `cream` vs `label` supplying a secondary
/// brightness step (`DODColor.cream` `#FAF6EE` reads visibly lighter than
/// `DODColor.label`'s toolbar-forced-dark `#E6DECF`) rather than a hue
/// change.
enum ToolbarGlyphForeground {

    /// Add to Shopping List + Share — neither carries a toggle state.
    static let neutral: Color = DODColor.label

    /// Save / bookmark glyph. Saved renders `DODColor.cream`; unsaved
    /// renders `DODColor.label`. State reads primarily through the
    /// `bookmark.fill` / `bookmark` SF Symbol swap in
    /// `RecipeDetailView+Toolbar.swift`.
    static func save(isSaved: Bool) -> Color {
        isSaved ? DODColor.cream : DODColor.label
    }

    /// Download glyph. Downloaded renders `DODColor.cream`; not-downloaded
    /// renders `DODColor.label`. State reads primarily through the
    /// `square.and.arrow.down.fill` / `square.and.arrow.down` SF Symbol swap
    /// in `RecipeDetailView+Toolbar.swift`.
    static func download(isDownloaded: Bool) -> Color {
        isDownloaded ? DODColor.cream : DODColor.label
    }
}
