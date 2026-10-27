import XCTest

@testable import DODCookActivity

final class CookActivityStandByModelTests: XCTestCase {
    func testSmoke() {
        // Smoke test to verify the public init works
        let model = CookActivityStandByModel(state: .init(remainingSeconds: 90, stepText: "Stir", isPaused: true))
        let view = CookActivityStandByView(recipeTitle: "Chili", model: model)
        XCTAssertTrue(view.model.status == .paused)
    }
}
