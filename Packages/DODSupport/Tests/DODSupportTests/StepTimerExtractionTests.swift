import Foundation
import Testing

@testable import DODSupport

@Suite("StepTimerExtraction") struct StepTimerExtractionTests {

    @Test func searPerSide() {
        let result = StepTimerExtraction.heuristic(from: "Sear 3 min per side")
        #expect(result.timers == [StepTimer(label: "Per side", seconds: 180)])
    }

    @Test func twoClausesTwoTimers() {
        let result = StepTimerExtraction.heuristic(from: "Sear 3 minutes, then rest 5 minutes")
        #expect(result.timers.map(\.seconds) == [180, 300])
    }

    @Test func singleClauseUnchanged() {
        #expect(StepTimerExtraction.heuristic(from: "Bake for 30 minutes").timers.first?.label == "Timer")
        #expect(StepTimerExtraction.heuristic(from: "Bake for 30 minutes").timers.first?.seconds == 1800)
    }

    @Test func multipleClausesMultipleTimers() {
        let result = StepTimerExtraction.heuristic(
            from: "Preheat oven to 350°F; cook for 2 hours; then stir for 10 minutes"
        )
        #expect(result.timers.map(\.seconds) == [7200, 600])  // 2 hours, 10 minutes
    }

    @Test func clauseWithTemperature() {
        let result = StepTimerExtraction.heuristic(from: "Bake for 30 minutes at 350°F")
        #expect(result.timers.first?.seconds == 1800)
        #expect(result.temperatureF == 350)
    }

    @Test func multipleTimersWithTemperature() {
        let result = StepTimerExtraction.heuristic(from: "Sear 3 min per side; then bake for 45 minutes at 375°F")
        #expect(result.timers.map(\.seconds) == [180, 2700])  // Per side, then 45 minutes
        #expect(result.temperatureF == 375)
    }

    @Test func clauseWithAnd() {
        let result = StepTimerExtraction.heuristic(from: "Cook for 1 hour and 30 minutes, then rest 20 minutes")
        #expect(result.timers.map(\.seconds) == [5400, 1200])  // 1h30m, then 20m
    }

    @Test func singleClauseWithMultipleTimers() {
        let result = StepTimerExtraction.heuristic(from: "Cook for 1 hour; rest for 30 minutes")
        #expect(result.timers.map(\.seconds) == [3600, 1800])  // 1h, then 30m
    }

    @Test func timerLimit() {
        let result = StepTimerExtraction.heuristic(
            from: "Cook for 1 hour; rest for 30 minutes; stir for 15 minutes; then bake for 2 hours"
        )
        #expect(result.timers.count == 2)  // Should only get first 2 timers
    }
}
