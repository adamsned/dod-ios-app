import XCTest

@testable import DODIntelligence

final class RecipeExtractionGroundingTests: XCTestCase {

    func testGroundedKeepsLinePresentInBody() {
        let body = "Use 2 cups of flour and 1 cup of sugar."
        let result = ExtractedRecipe(
            ingredients: ["2 cups of flour", "1 cup of sugar"],
            instructions: []
        )

        let groundedResult = LiveDODIntelligenceService.grounded(result, in: body)

        XCTAssertEqual(groundedResult.ingredients.count, 2)
        XCTAssertTrue(groundedResult.ingredients.contains("2 cups of flour"))
        XCTAssertTrue(groundedResult.ingredients.contains("1 cup of sugar"))
    }

    func testGroundedDropsInventedLine() {
        let body = "Use 2 cups of flour and 1 cup of sugar."
        let result = ExtractedRecipe(
            ingredients: ["2 cups of flour", "1 tsp saffron", "1 cup of sugar"],
            instructions: []
        )

        let groundedResult = LiveDODIntelligenceService.grounded(result, in: body)

        XCTAssertEqual(groundedResult.ingredients.count, 2)
        XCTAssertTrue(groundedResult.ingredients.contains("2 cups of flour"))
        XCTAssertTrue(groundedResult.ingredients.contains("1 cup of sugar"))
        XCTAssertFalse(groundedResult.ingredients.contains("1 tsp saffron"))
    }

    func testExtractionPromptContainsChunk() {
        let chunk = "This is a recipe chunk with ingredients and steps."
        let prompt = LiveDODIntelligenceService.extractionPrompt(chunk: chunk)

        XCTAssertTrue(prompt.contains(chunk))
    }

    func testExtractRecipeReturnsNilOnMacOS() {
        // This test should run on macOS where iOS availability checks would fail
        #if os(macOS)
        let result = LiveDODIntelligenceService.extractRecipe(fromBody: "x")
        XCTAssertNil(result)
        #endif
    }
}
