import Testing

@Suite
struct CookQuestionIntentTests {
    
    @Test
    func whatsNextGivesNextStep() {
        let result = CookQuestionIntent.classify("What's next?")
        #expect(result == .nextStep)
    }
    
    @Test
    func goBackGivesPreviousStep() {
        let result = CookQuestionIntent.classify("go back")
        #expect(result == .previousStep)
    }
    
    @Test
    func repeatThatGivesRepeatStep() {
        let result = CookQuestionIntent.classify("Repeat that")
        #expect(result == .repeatStep)
    }
    
    @Test
    func emptyStringGivesEmpty() {
        let result = CookQuestionIntent.classify("   ")
        #expect(result == .empty)
    }
    
    @Test
    func questionGivesAsk() {
        let result = CookQuestionIntent.classify("How much salt again?")
        #expect(result == .ask("How much salt again?"))
    }
}