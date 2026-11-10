import Foundation
import Testing

@testable import DODIntelligence

@Suite
struct DonenessPromptTests {
    @Test
    func promptContainsStepText() {
        let prompt = LiveDODIntelligenceService.donenessPrompt(stepText: "Bake until golden")
        #expect(prompt.contains("Bake until golden"))
    }

    @Test
    func promptTruncatesLongStep() {
        let prompt = LiveDODIntelligenceService.donenessPrompt(
            stepText: String(repeating: "a", count: 2000)
        )
        #expect(!prompt.contains(String(repeating: "a", count: 1001)))
        #expect(prompt.contains(String(repeating: "a", count: 1000)))
    }

    @Test
    func mapsNotYet() {
        let result = LiveDODIntelligenceService.mapDoneness(
            verdict: "notYet",
            confidence: 0.9,
            reassurance: "Pale"
        )
        #expect(result?.verdict == .notYet)
    }

    @Test
    func lowConfidenceIsUnsure() {
        let result = LiveDODIntelligenceService.mapDoneness(
            verdict: "looksDone",
            confidence: 0.2,
            reassurance: "Golden"
        )
        #expect(result?.verdict == .unsure)
    }

    @Test
    func instructionsForbidTemperature() {
        #expect(LiveDODIntelligenceService.donenessInstructions.contains("NEVER"))
    }
}
