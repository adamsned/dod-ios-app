import XCTest
@testable import DODFeatureRecipeDetail

final class CookModeSpokenAnswersTests: XCTestCase {

    func testIngredientAnswer() {
        // Test case 1: Should find salt
        let result1 = CookModeSpokenAnswers.ingredientAnswer(
            question: "How much salt again?",
            ingredientLines: ["1 tsp salt", "2 cups flour"]
        )
        XCTAssertEqual(result1, "1 tsp salt")
        
        // Test case 2: Should return nil when no match
        let result2 = CookModeSpokenAnswers.ingredientAnswer(
            question: "How much butter?",
            ingredientLines: ["1 tsp salt"]
        )
        XCTAssertNil(result2)
    }
    
    func testWhatsNext() {
        // Test case 1: Should return next step
        let steps = [
            RecipeInstruction(step: 1, text: "Mix."),
            RecipeInstruction(step: 2, text: "Bake.")
        ]
        let result1 = CookModeSpokenAnswers.whatsNext(steps: steps, currentStepIndex: 0)
        XCTAssertEqual(result1, "Step 2. Bake.")
        
        // Test case 2: Should return last step message
        let result2 = CookModeSpokenAnswers.whatsNext(steps: steps, currentStepIndex: 1)
        XCTAssertEqual(result2, "That was the last step.")
    }
}