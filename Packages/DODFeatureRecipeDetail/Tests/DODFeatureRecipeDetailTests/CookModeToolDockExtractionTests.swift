import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-1873 — the dock surfaces the second timer and temperature from the heuristic extraction.
@MainActor
@Suite("Cook Mode tool dock extraction (DUT-1873)")
struct CookModeToolDockExtractionTests {

    private func resolve(_ text: String) -> CookModeToolDockContent {
        CookModeToolDockContent.resolve(
            currentStepIndex: 0,
            stepText: text,
            heatCoachAvailable: false,
            timers: [:],
            now: Date(timeIntervalSince1970: 1_000_000)
        )
    }

    @Test func stepWithTwoTimersAndTemp() {
        let content = resolve("Preheat to 400°F. Sear 3 minutes, then rest 5 minutes")
        #expect(content.stepTimerDuration == .seconds(180))
        #expect(content.secondTimerDuration == .seconds(300))
        #expect(content.stepTemperatureF == 400)
    }

    @Test func plainStepStillEmpty() {
        #expect(resolve("Stir gently").isEmpty)
    }

    @Test func singleTimerHasNoSecondTimer() {
        let content = resolve("Simmer for 10 minutes.")
        #expect(content.stepTimerDuration == .seconds(600))
        #expect(content.secondTimerDuration == nil)
        #expect(content.stepTemperatureF == nil)
    }
}
