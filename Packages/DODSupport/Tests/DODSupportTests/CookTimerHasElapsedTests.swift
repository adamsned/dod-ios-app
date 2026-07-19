import Foundation
import Testing

@testable import DODSupport

/// L1 coverage for ``CookTimer/hasElapsed(at:)`` — previously untested (zero
/// references anywhere in the repo). Pure value type, no mocks needed.
@Suite("CookTimer.hasElapsed(at:)") struct CookTimerHasElapsedTests {
    @Test func runningBeforeEndDateHasNotElapsed() {
        let baseDate = Date(timeIntervalSince1970: 1000)
        let timer = CookTimer(
            id: UUID(),
            label: "Bake",
            duration: 600,
            state: .running(endDate: baseDate.addingTimeInterval(60)),
            recipeID: nil
        )
        let now = baseDate.addingTimeInterval(30)

        #expect(timer.hasElapsed(at: now) == false)
    }

    @Test func runningAtExactEndDateHasElapsed() {
        let baseDate = Date(timeIntervalSince1970: 1000)
        let timer = CookTimer(
            id: UUID(),
            label: "Bake",
            duration: 600,
            state: .running(endDate: baseDate.addingTimeInterval(60)),
            recipeID: nil
        )
        let now = baseDate.addingTimeInterval(60)

        #expect(timer.hasElapsed(at: now) == true)
    }

    @Test func runningPastEndDateHasElapsed() {
        let baseDate = Date(timeIntervalSince1970: 1000)
        let timer = CookTimer(
            id: UUID(),
            label: "Bake",
            duration: 600,
            state: .running(endDate: baseDate.addingTimeInterval(60)),
            recipeID: nil
        )
        let now = baseDate.addingTimeInterval(90)

        #expect(timer.hasElapsed(at: now) == true)
    }

    @Test func pausedNeverHasElapsed() {
        let timer = CookTimer(id: UUID(), label: "Bake", duration: 600, state: .paused(remaining: 30), recipeID: nil)

        #expect(timer.hasElapsed(at: Date(timeIntervalSince1970: 2000)) == false)
    }

    @Test func finishedAlwaysHasElapsed() {
        let timer = CookTimer(id: UUID(), label: "Bake", duration: 600, state: .finished, recipeID: nil)

        #expect(timer.hasElapsed(at: Date(timeIntervalSince1970: 3000)) == true)
    }

    /// Pause freezes elapsed-ness even at a `now` far past what would have
    /// been the deadline had the timer kept running — not a coincidence of a
    /// nearby `now`.
    @Test func pausedFreezesElapsedEvenFarInTheFuture() {
        let timer = CookTimer(id: UUID(), label: "Bake", duration: 600, state: .paused(remaining: 15), recipeID: nil)

        #expect(timer.hasElapsed(at: Date(timeIntervalSince1970: 1_000_000)) == false)
    }
}
