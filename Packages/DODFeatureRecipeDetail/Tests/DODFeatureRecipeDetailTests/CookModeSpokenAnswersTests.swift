import DODDomain
import Testing

@testable import DODFeatureRecipeDetail

@Suite("CookModeSpokenAnswers") struct CookModeSpokenAnswersTests {
    private let steps = [
        RecipeInstruction(step: 1, text: "Chop onions."),
        RecipeInstruction(step: 2, text: "Sear the beef."),
    ]

    private let lines = ["2 cups flour", "1/2 cup butter"]

    @Test func whatsNextReadsFollowingStep() {
        let text = CookModeSpokenAnswers.whatsNext(steps: steps, currentStepIndex: 0)
        #expect(text == "Next: Sear the beef.")
    }

    @Test func whatsNextOnLastStepSaysSo() {
        let text = CookModeSpokenAnswers.whatsNext(steps: steps, currentStepIndex: 1)
        #expect(text == "That's the last step.")
    }

    @Test func ingredientAnswerFindsMatchingLine() {
        let text = CookModeSpokenAnswers.ingredientAnswer(
            question: "How much butter do I need?",
            ingredientLines: lines
        )
        #expect(text == "The recipe lists 1/2 cup butter.")
    }

    @Test func ingredientAnswerIgnoresNonQuantityQuestions() {
        let text = CookModeSpokenAnswers.ingredientAnswer(question: "Can I swap the butter?", ingredientLines: lines)
        #expect(text == nil)
    }

    @Test func ingredientAnswerNilWhenNoLineMatches() {
        let text = CookModeSpokenAnswers.ingredientAnswer(question: "How much saffron?", ingredientLines: lines)
        #expect(text == nil)
    }
}
