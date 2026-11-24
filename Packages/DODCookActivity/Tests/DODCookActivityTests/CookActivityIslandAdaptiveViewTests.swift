import Foundation
import Testing

@testable import DODCookActivity

@Suite("CookActivityIslandAdaptiveView")
struct CookActivityIslandAdaptiveViewTests {
    @Test func constructsWithContentStateInputs() {
        let view = CookActivityIslandAdaptiveView(
            recipeTitle: "Chili",
            stepText: "Simmer",
            remainingSeconds: 60,
            totalSeconds: 600,
            isPaused: false
        )
        #expect(view.remainingSeconds == 60)
        #expect(view.isCompleted == false)
        #expect(view.endDate == nil)
    }
}
