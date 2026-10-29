import Testing

@testable import DODIntelligence

@Suite("AskRecipeInstructions")
struct AskRecipeInstructionsTests {
    @Test func instructionsRequireToolsAndForbidInventedQuantities() {
        let text = LiveDODIntelligenceService.askRecipeInstructions
        #expect(text.contains("Always call tools"))
        #expect(text.contains("Never invent or calculate quantities"))
    }
}
