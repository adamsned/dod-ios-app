import XCTest

@testable import DODIntelligence

final class ExplainStepPromptTests: XCTestCase {

    func testPromptContainsStepAndNext() {
        let prompt = LiveDODIntelligenceService.explainStepPrompt(
            step: "Fold in the egg whites",
            nextStep: "Bake"
        )
        XCTAssertTrue(prompt.contains("Step to explain: Fold in the egg whites"))
        XCTAssertTrue(prompt.contains("Next step (context only): Bake"))
    }

    func testPromptOmitsNextWhenNil() {
        let prompt = LiveDODIntelligenceService.explainStepPrompt(
            step: "Fold in the egg whites",
            nextStep: nil
        )
        XCTAssertFalse(prompt.contains("Next step"))
    }

    func testInstructionsForbidInventedNumbers() {
        XCTAssertTrue(LiveDODIntelligenceService.explainStepInstructions.contains("NEVER add a temperature"))
    }

    func testLiveReturnsNilForEmptyStep() async {
        let service = LiveDODIntelligenceService()
        XCTAssertNil(await service.explainStep("  ", nextStep: nil))
    }
}
