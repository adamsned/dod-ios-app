import Testing

@testable import DODFeatureRecipeDetail

@Suite
struct CookModeLayoutTests {

    @Test
    func resolveWithRegularSizeClass() {
        #expect(CookModeLayout.resolve(horizontalSizeClass: .regular) == .twoPane)
    }

    @Test
    func resolveWithCompactSizeClass() {
        #expect(CookModeLayout.resolve(horizontalSizeClass: .compact) == .stacked)
    }

    @Test
    func resolveWithNilSizeClass() {
        #expect(CookModeLayout.resolve(horizontalSizeClass: nil) == .stacked)
    }

    @Test
    func pinnedPaneWidth() {
        #expect(CookModeLayout.pinnedPaneWidth(containerWidth: 1000) == 380)
    }
}
