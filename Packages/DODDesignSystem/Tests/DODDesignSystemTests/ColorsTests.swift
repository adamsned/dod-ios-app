import SwiftUI
import Testing

@testable import DODDesignSystem

@Suite("DODColor catalog") struct ColorsTests {

    /// Smoke test: ensure every semantic token resolves to a non-default color.
    /// `Color(_:bundle:)` returns a placeholder pink if an asset is missing,
    /// so we round-trip through `Color.description` to spot that.
    @Test func semanticColorsResolve() {
        let semantic: [Color] = [
            DODColor.surface,
            DODColor.surfaceElevated,
            DODColor.surfaceWarm,
            DODColor.surfaceDivider,
            DODColor.label,
            DODColor.labelSecondary,
            DODColor.labelOnAccent,
            DODColor.accent,
        ]
        for color in semantic {
            #expect(!color.description.contains("placeholder"))
        }
    }

    @Test func brandColorsResolve() {
        let brand: [Color] = [
            DODColor.castIronBrown,
            DODColor.burntOrange,
            DODColor.warmGold,
            DODColor.cream,
            DODColor.charcoal,
            DODColor.darkEarth,
        ]
        for color in brand {
            #expect(!color.description.contains("placeholder"))
        }
    }
}

// MARK: - v2 "Seasoned Cast Iron" OLED surface resolution

#if canImport(UIKit)
import UIKit

/// Verifies the four background/surface tokens swap to their true-OLED hexes
/// ONLY when `DODColor.isOLEDDark` is set AND the trait is dark, and otherwise
/// resolve to the asset-catalog value. `.serialized` + the `deinit` reset keep
/// the mutated process-global from leaking into the parallel snapshot/color
/// suites (a leaked `true` would render every dark snapshot black).
@Suite("DODColor OLED surfaces (v2)", .serialized) struct DODColorOLEDTests {

    private let dark = UITraitCollection(userInterfaceStyle: .dark)
    private let light = UITraitCollection(userInterfaceStyle: .light)

    init() { DODColor.isOLEDDark = false }
    // tearDown equivalent — never let the global leak past a test.
    deinit { DODColor.isOLEDDark = false }

    /// Resolve a SwiftUI `Color` to concrete 8-bit `[R, G, B]` under a trait.
    private func rgb(_ color: Color, _ traits: UITraitCollection) -> [Int] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).resolvedColor(with: traits)
            .getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue].map { Int(($0 * 255).rounded()) }
    }

    @Test func oledFlagSwapsSurfacesInDarkTrait() {
        DODColor.isOLEDDark = true
        #expect(rgb(DODColor.surface, dark) == [0x00, 0x00, 0x00])
        #expect(rgb(DODColor.surfaceElevated, dark) == [0x1C, 0x1C, 0x1E])
        #expect(rgb(DODColor.surfaceWarm, dark) == [0x1C, 0x1C, 0x1E])
        #expect(rgb(DODColor.surfaceDivider, dark) == [0x38, 0x38, 0x3A])
    }

    @Test func oledFlagLeavesLightTraitOnAssetValue() {
        DODColor.isOLEDDark = true
        // Light surface is the asset's `#FFFFFF` — the OLED swap is dark-only.
        #expect(rgb(DODColor.surface, light) == [0xFF, 0xFF, 0xFF])
    }

    @Test func flagOffKeepsAssetDarkValue() {
        DODColor.isOLEDDark = false
        // Cocoa dark Surface is the warm-brown `#1B140E`, NOT black.
        #expect(rgb(DODColor.surface, dark) == [0x1B, 0x14, 0x0E])
        #expect(rgb(DODColor.surface, dark) != [0x00, 0x00, 0x00])
    }
}
#endif
