import SwiftUI

/// Brand palette + semantic colors. Backed by the `Colors.xcassets` catalog
/// bundled inside this module — light/dark variants are baked in.
///
/// Plan trace: plan.md §5. US-43 / CL-110..CL-114 (T-710, 2026-05-29) added
/// `surfaceWarm`, `surfaceDivider`, `labelOnAccent`, and renamed the prior
/// `creamSubtle` to `surfaceDivider` to make the role-explicit divider
/// intent clear. `surfaceWarm` + `labelOnAccent` are reserved-but-unused in
/// Phase a — Phase b (T-711) + Phase c (T-712) + Phase d (T-713) wire them.
public enum DODColor {

    // MARK: - Semantic tokens (use these in features)

    /// Default screen background.
    ///
    /// US-43 / AC-43.1 (T-710, 2026-05-29) — light = `#FFFFFF` (matches the
    /// dutchovendaddy.com white backdrop), dark = `#1B140E` (deeper warm-brown
    /// than the prior T-520 / CL-51 `#42210B`, per CL-111).
    public static let surface = bundleColor("Surface")
    /// Card / sheet surface above ``surface``.
    ///
    /// US-43 / AC-43.2 (T-710, 2026-05-29) — light = `#FFFFFF` (collapses to
    /// `Surface` on light mode so cards read as borderless), dark = `#281F19`.
    public static let surfaceElevated = bundleColor("SurfaceElevated")
    /// Warm cream surface for the Saved tab + empty states + Cook Mode
    /// background. Reserved-but-unused in Phase a — Phase b (T-711) +
    /// Phase d (T-713) wire it.
    ///
    /// US-43 / AC-43.3 (T-710, 2026-05-29) — light = `#FAF6EE`, dark = `#281F19`.
    public static let surfaceWarm = bundleColor("SurfaceWarm")
    /// Thin section dividers + sticky-header tint surfaces. Renamed from
    /// the prior `creamSubtle` per CL-112 — the role is divider, not warm
    /// cream backdrop (use ``surfaceWarm`` for that).
    ///
    /// US-43 / AC-43.4 (T-710, 2026-05-29) — light = `#E6DECF`, dark =
    /// `#3D2B1F` (the prior `CreamSubtle.colorset` kept the same hex in
    /// both appearances, which made dividers indistinguishable in dark
    /// mode — the new dark variant restores the divider read in dark
    /// Cook Mode).
    public static let surfaceDivider = bundleColor("SurfaceDivider")
    /// Primary body text color.
    public static let label = bundleColor("Label")
    /// Maximum-contrast label for large screen titles (``DODScreenHeader``).
    ///
    /// DUT-263 — pure `#000000` light / `#FFFFFF` dark, where ``label`` is the
    /// warmer brand `#2C2C2C` / `#E6DECF`. Tester feedback was that the
    /// brand-grey/cream large titles read as washed out; the screen header
    /// wants true black/white so every tab's title pops identically. Scoped to
    /// the header — body copy stays on ``label``.
    public static let labelStrong = bundleColor("LabelStrong")
    /// Secondary / supporting text color.
    public static let labelSecondary = bundleColor("LabelSecondary")
    /// Text rendered on top of an ``accent``-filled surface (the burnt-orange
    /// numbered "Popular" badge that ships in Phase c). Reserved-but-unused
    /// in Phase a — Phase c (T-712) wires it.
    ///
    /// US-43 / AC-43.5 (T-710, 2026-05-29) — light = `#FFFFFF`, dark = `#FFFFFF`.
    public static let labelOnAccent = bundleColor("LabelOnAccent")
    /// Brand accent (save bookmark, primary buttons).
    public static let accent = bundleColor("Accent")

    // MARK: - Raw brand palette (for design system internals)

    public static let castIronBrown = bundleColor("CastIronBrown")
    public static let burntOrange = bundleColor("BurntOrange")
    public static let warmGold = bundleColor("WarmGold")
    public static let cream = bundleColor("Cream")
    public static let charcoal = bundleColor("Charcoal")
    public static let darkEarth = bundleColor("DarkEarth")

    private static func bundleColor(_ name: String) -> Color {
        Color(name, bundle: .module)
    }
}
