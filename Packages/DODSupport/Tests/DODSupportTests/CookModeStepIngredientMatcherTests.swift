import XCTest

@testable import DODSupport

final class CookModeStepIngredientMatcherTests: XCTestCase {

    func testMatchesWholeWordCaseInsensitively() {
        let stepText = "Sear the SHORT RIBS"
        let ingredients = ["2 lb short ribs", "1 cup flour"]
        let result = CookModeStepIngredientMatcher.matching(stepText: stepText, ingredients: ingredients)
        XCTAssertEqual(result, ["2 lb short ribs"])
    }

    func testIgnoresUnitAndPrepNoise() {
        let stepText = "Add 1 cup"
        let ingredients = ["1 cup flour", "2 tbsp salt"]
        let result = CookModeStepIngredientMatcher.matching(stepText: stepText, ingredients: ingredients)
        XCTAssertEqual(result, [])
    }

    func testNoMatchReturnsEmpty() {
        let stepText = "Mix well"
        let ingredients = ["1 cup flour", "2 tbsp salt"]
        let result = CookModeStepIngredientMatcher.matching(stepText: stepText, ingredients: ingredients)
        XCTAssertEqual(result, [])
    }

    func testPreservesIngredientOrder() {
        let stepText = "Add the flour"
        let ingredients = ["2 tbsp salt", "1 cup flour", "1 tsp sugar"]
        let result = CookModeStepIngredientMatcher.matching(stepText: stepText, ingredients: ingredients)
        XCTAssertEqual(result, ["1 cup flour"])
    }
}
