import Testing

@testable import DODIntelligence

@Suite("AskRecipeInstructions")
struct AskRecipeInstructionsTests {
    @Test func instructionsRequireToolsAndForbidInventedQuantities() {
        let text = LiveDODIntelligenceService.askRecipeInstructions
        #expect(text.contains("Always call tools"))
        #expect(text.contains("Never invent or calculate quantities"))
    }

    @Test func instructionsForbidSanding() {
        let text = LiveDODIntelligenceService.askRecipeInstructions
        #expect(text.contains("Never, ever mention, suggest or describe sanding"))
        #expect(text.contains("steel wool"))
    }
}
