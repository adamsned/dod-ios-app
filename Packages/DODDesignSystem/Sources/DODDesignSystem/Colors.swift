import SwiftUI

/// Brand palette + semantic colors. Backed by the `Colors.xcassets` catalog
/// bundled inside this module — light/dark variants are baked in.
///
/// Plan trace: plan.md §5.
public enum DODColor {

    // MARK: - Semantic tokens (use these in features)

    /// Default screen background.
    public static let surface = bundleColor("Surface")
    /// Card / sheet surface above ``surface``.
    public static let surfaceElevated = bundleColor("SurfaceElevated")
    /// Primary body text color.
    public static let label = bundleColor("Label")
    /// Secondary / supporting text color.
    public static let labelSecondary = bundleColor("LabelSecondary")
    /// Brand accent (save heart, primary buttons).
    public static let accent = bundleColor("Accent")

    // MARK: - Raw brand palette (for design system internals)

    public static let castIronBrown = bundleColor("CastIronBrown")
    public static let burntOrange = bundleColor("BurntOrange")
    public static let warmGold = bundleColor("WarmGold")
    public static let cream = bundleColor("Cream")
    public static let charcoal = bundleColor("Charcoal")
    public static let darkEarth = bundleColor("DarkEarth")
    public static let creamSubtle = bundleColor("CreamSubtle")

    private static func bundleColor(_ name: String) -> Color {
        Color(name, bundle: .module)
    }
}
