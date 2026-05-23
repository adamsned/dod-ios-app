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
            DODColor.label,
            DODColor.labelSecondary,
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
            DODColor.creamSubtle,
        ]
        for color in brand {
            #expect(!color.description.contains("placeholder"))
        }
    }
}
