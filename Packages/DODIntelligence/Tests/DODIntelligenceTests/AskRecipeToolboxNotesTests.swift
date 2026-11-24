import XCTest

@testable import DODIntelligence

final class AskRecipeToolboxNotesTests: XCTestCase {
    func testMakeAheadHintsFindsChillStepsDeduped() {
        let toolbox = AskRecipeToolbox(
            title: "Test Recipe",
            servings: 4,
            scaledIngredients: [],
            steps: [
                "Preheat oven to 350°F.",
                "Cool completely, then refrigerate overnight.",  // matches 3 keywords, listed once
                "Mix ingredients.",
            ]
        )

        XCTAssertEqual(toolbox.makeAheadHints(), ["2. Cool completely, then refrigerate overnight."])
    }

    func testMakeAheadHintsEmptyWhenNone() {
        let toolbox = AskRecipeToolbox(
            title: "Test Recipe",
            servings: 4,
            scaledIngredients: [],
            steps: [
                "1. Preheat oven to 350°F.",
                "2. Mix ingredients.",
                "3. Bake for 30 minutes.",
            ]
        )

        let hints = toolbox.makeAheadHints()
        XCTAssertTrue(hints.isEmpty)
    }

    func testServingsLineSingularPluralAndNil() {
        let toolbox1 = AskRecipeToolbox(
            title: "Test Recipe",
            servings: 1,
            scaledIngredients: [],
            steps: []
        )
        XCTAssertEqual(toolbox1.servingsLine(), "Makes 1 serving")

        let toolbox2 = AskRecipeToolbox(
            title: "Test Recipe",
            servings: 4,
            scaledIngredients: [],
            steps: []
        )
        XCTAssertEqual(toolbox2.servingsLine(), "Makes 4 servings")

        let toolbox3 = AskRecipeToolbox(
            title: "Test Recipe",
            servings: nil,
            scaledIngredients: [],
            steps: []
        )
        XCTAssertEqual(toolbox3.servingsLine(), "Serving count not listed")
    }
}
