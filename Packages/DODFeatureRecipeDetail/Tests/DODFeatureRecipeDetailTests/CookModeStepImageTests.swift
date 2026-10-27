import SwiftUI
import Testing

@testable import DODFeatureRecipeDetail

struct CookModeStepImageTests {
    @Test
    func maxHeightReturnsCorrectValueForLargeSize() {
        #expect(CookModeStepImage.maxHeight(for: .large) == 220)
    }

    @Test
    func maxHeightReturnsCorrectValueForAccessibilitySize() {
        #expect(CookModeStepImage.maxHeight(for: .accessibility3) == 120)
    }
}
