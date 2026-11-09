import DODDomain
import Testing

@testable import DODFeatureRecipeDetail

@Suite("CookModeSpokenAnswers") struct CookModeSpokenAnswersTests {
    private let steps = [
        RecipeInstruction(step: 1, text: "Chop onions."),
        RecipeInstruction(step: 2, text: "Sear the beef."),
    ]

    @Test func whatsNextReadsFollowingStep() {
        let text = CookModeSpokenAnswers.whatsNext(steps: steps, currentStepIndex: 0)
        #expect(text == "Next: Sear the beef.")
    }

    @Test func whatsNextOnLastStepSaysSo() {
        let text = CookModeSpokenAnswers.whatsNext(steps: steps, currentStepIndex: 1)
        #expect(text == "That's the last step.")
    }
}
