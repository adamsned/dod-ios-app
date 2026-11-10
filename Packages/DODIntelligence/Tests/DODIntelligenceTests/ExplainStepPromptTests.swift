import Testing

@testable import DODIntelligence

@Suite("ExplainStepPrompt")
struct ExplainStepPromptTests {

    @Test func testPromptContainsStepAndNext() {
        let prompt = LiveDODIntelligenceService.explainStepPrompt(
            step: "Fold in the egg whites",
            nextStep: "Bake"
        )
        #expect(prompt.contains("Step to explain: Fold in the egg whites"))
        #expect(prompt.contains("Next step (context only): Bake"))
    }

    @Test func testPromptOmitsNextWhenNil() {
        let prompt = LiveDODIntelligenceService.explainStepPrompt(
            step: "Fold in the egg whites",
            nextStep: nil
        )
        #expect(!prompt.contains("Next step"))
    }

    @Test func testInstructionsForbidInventedNumbers() {
        #expect(LiveDODIntelligenceService.explainStepInstructions.contains("NEVER add a temperature"))
    }

    @Test func testLiveReturnsNilForEmptyStep() async {
        let service = LiveDODIntelligenceService()
        #expect(await service.explainStep("  ", nextStep: nil) == nil)
    }
}
