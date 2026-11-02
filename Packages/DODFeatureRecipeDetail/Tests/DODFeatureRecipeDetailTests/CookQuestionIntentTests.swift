import Testing

@testable import DODFeatureRecipeDetail

@Suite("Cook question intent") struct CookQuestionIntentTests {

    @Test func whatsNextIsNextStep() {
        #expect(CookQuestionIntent.classify("What's next?") == .nextStep)
    }

    @Test func goBackIsPreviousStep() {
        #expect(CookQuestionIntent.classify("go back") == .previousStep)
    }

    @Test func repeatThatIsRepeatStep() {
        #expect(CookQuestionIntent.classify("Repeat that") == .repeatStep)
    }

    @Test func blankIsEmpty() {
        #expect(CookQuestionIntent.classify("   ") == .empty)
    }

    @Test func otherTextIsAQuestion() {
        #expect(CookQuestionIntent.classify("How much salt again?") == .ask("How much salt again?"))
    }
}
