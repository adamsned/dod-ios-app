import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Brand palette + semantic colors. Backed by the `Colors.xcassets` catalog
/// bundled inside this module — light/dark variants are baked in.
///
/// Plan trace: plan.md §5. US-43 / CL-110..CL-114 (T-710, 2026-05-29) added
/// `surfaceWarm`, `surfaceDivider`, `labelOnAccent`, and renamed the prior
/// `creamSubtle` to `surfaceDivider` to make the role-explicit divider
/// intent clear. `surfaceWarm` + `labelOnAccent` are reserved-but-unused in
/// Phase a — Phase b (T-711) + Phase c (T-712) + Phase d (T-713) wire them.
public enum DODColor {

    // MARK: - OLED "Seasoned Cast Iron" theme flag (v2)

    /// Process-global that flips the four background/surface tokens to their
    /// true-OLED hexes under the dark trait, backing the v2 "Seasoned Cast Iron"
    /// App Appearance theme. DODDesignSystem cannot import DODFeatureFeed (where
    /// `AppearancePreference` lives), so this is a plain bool set BY the app: at
    /// launch from `AppearancePreference.fromDefaults(...).isOLEDDark`, and on
    /// every appearance change (RootView + SettingsView). Read inside the dynamic
    /// `UIColor` providers below, which only re-run on a trait change — Cocoa→
    /// Seasoned is dark→dark (no trait change), so the app additionally forces a
    /// view re-resolution (`.id(appearance)`) after mutating this. Every non-OLED
    /// theme (including "Cocoa") leaves it `false`, so the asset-catalog dark
    /// values are untouched.
    nonisolated(unsafe) public static var isOLEDDark = false

    // MARK: - Semantic tokens (use these in features)

    /// Default screen background.
    ///
    /// US-43 / AC-43.1 (T-710, 2026-05-29) — light = `#FFFFFF` (matches the
    /// dutchovendaddy.com white backdrop), dark = `#1B140E` (deeper warm-brown
    /// than the prior T-520 / CL-51 `#42210B`, per CL-111).
    ///
    /// v2 OLED — when ``isOLEDDark`` is set and the trait is dark, resolves to
    /// deep black `#000000` instead of the asset's warm-brown dark value.
    public static var surface: Color { themedSurface("Surface", oledDark: 0x000000) }
    /// Card / sheet surface above ``surface``.
    ///
    /// US-43 / AC-43.2 (T-710, 2026-05-29) — light = `#FFFFFF` (collapses to
    /// `Surface` on light mode so cards read as borderless), dark = `#281F19`.
    ///
    /// v2 OLED — dark trait + ``isOLEDDark`` resolves to the elevated OLED gray
    /// `#1C1C1E` (the slightly-lighter-than-black card surface).
    public static var surfaceElevated: Color { themedSurface("SurfaceElevated", oledDark: 0x1C1C1E) }
    /// Warm cream surface for the Saved tab + empty states + Cook Mode
    /// background. Reserved-but-unused in Phase a — Phase b (T-711) +
    /// Phase d (T-713) wire it.
    ///
    /// US-43 / AC-43.3 (T-710, 2026-05-29) — light = `#FAF6EE`, dark = `#281F19`.
    ///
    /// v2 OLED — dark trait + ``isOLEDDark`` resolves to the elevated OLED gray
    /// `#1C1C1E` (matches ``surfaceElevated``).
    public static var surfaceWarm: Color { themedSurface("SurfaceWarm", oledDark: 0x1C1C1E) }
    /// Thin section dividers + sticky-header tint surfaces. Renamed from
    /// the prior `creamSubtle` per CL-112 — the role is divider, not warm
    /// cream backdrop (use ``surfaceWarm`` for that).
    ///
    /// US-43 / AC-43.4 (T-710, 2026-05-29) — light = `#E6DECF`, dark =
    /// `#3D2B1F` (the prior `CreamSubtle.colorset` kept the same hex in
    /// both appearances, which made dividers indistinguishable in dark
    /// mode — the new dark variant restores the divider read in dark
    /// Cook Mode).
    ///
    /// v2 OLED — dark trait + ``isOLEDDark`` resolves to the OLED separator gray
    /// `#38383A`.
    public static var surfaceDivider: Color { themedSurface("SurfaceDivider", oledDark: 0x38383A) }
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

    /// v2 OLED — a dynamic surface color that resolves to the asset-catalog
    /// value for every appearance EXCEPT the true-OLED "Seasoned Cast Iron"
    /// theme in the dark trait, where it returns the supplied `oledDark` hex.
    /// The `UIColor` provider re-evaluates on trait changes; a Cocoa→Seasoned
    /// switch is dark→dark (no trait change), so the app forces a view
    /// re-resolution after flipping ``isOLEDDark`` (see RootView / SettingsView).
    private static func themedSurface(_ assetName: String, oledDark hex: Int) -> Color {
        #if canImport(UIKit)
        return Color(
            UIColor { traits in
                if isOLEDDark, traits.userInterfaceStyle == .dark {
                    return UIColor(
                        red: CGFloat((hex >> 16) & 0xFF) / 255,
                        green: CGFloat((hex >> 8) & 0xFF) / 255,
                        blue: CGFloat(hex & 0xFF) / 255,
                        alpha: 1
                    )
                }
                return UIColor(named: assetName, in: .module, compatibleWith: traits) ?? .clear
            }
        )
        #else
        return Color(assetName, bundle: .module)
        #endif
    }
}
