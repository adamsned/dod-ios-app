import Foundation
import Testing
@testable import DODSupport

@Suite
struct CookTimerTransitionsTests {
    let timerID = UUID()

    // MARK: - remaining(at:) contracts

    @Test func remainingCountdownRunning() {
        let now = Date(timeIntervalSince1970: 1000)
        let endDate = Date(timeIntervalSince1970: 1060)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .running(endDate: endDate))

        #expect(timer.remaining(at: now) == 60)
        #expect(timer.remaining(at: Date(timeIntervalSince1970: 1030)) == 30)
        #expect(timer.remaining(at: endDate) == 0)
    }

    @Test func remainingClampedNonNegative() {
        let endDate = Date(timeIntervalSince1970: 1060)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .running(endDate: endDate))

        #expect(timer.remaining(at: Date(timeIntervalSince1970: 1070)) == 0)
        #expect(timer.remaining(at: Date(timeIntervalSince1970: 2000)) == 0)
    }

    @Test func remainingPausedHoldsFrozen() {
        let now = Date(timeIntervalSince1970: 1000)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .paused(remaining: 50))

        #expect(timer.remaining(at: now) == 50)
        #expect(timer.remaining(at: Date(timeIntervalSince1970: 1010)) == 50)
        #expect(timer.remaining(at: Date(timeIntervalSince1970: 2000)) == 50)
    }

    @Test func remainingPausedClampedNonNegative() {
        let now = Date(timeIntervalSince1970: 1000)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .paused(remaining: -10))

        #expect(timer.remaining(at: now) == 0)
    }

    @Test func remainingFinishedAlwaysZero() {
        let now = Date(timeIntervalSince1970: 1000)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .finished)

        #expect(timer.remaining(at: now) == 0)
        #expect(timer.remaining(at: Date(timeIntervalSince1970: 2000)) == 0)
    }

    // MARK: - hasElapsed(at:) contracts

    @Test func hasElapsedRunningFalseBeforeEndDate() {
        let now = Date(timeIntervalSince1970: 1000)
        let endDate = Date(timeIntervalSince1970: 1060)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .running(endDate: endDate))

        #expect(timer.hasElapsed(at: now) == false)
        #expect(timer.hasElapsed(at: Date(timeIntervalSince1970: 1030)) == false)
    }

    @Test func hasElapsedRunningTrueAtOrAfterEndDate() {
        let endDate = Date(timeIntervalSince1970: 1060)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .running(endDate: endDate))

        #expect(timer.hasElapsed(at: endDate) == true)
        #expect(timer.hasElapsed(at: Date(timeIntervalSince1970: 1070)) == true)
    }

    @Test func hasElapsedPausedAlwaysFalse() {
        let now = Date(timeIntervalSince1970: 1000)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .paused(remaining: 30))

        #expect(timer.hasElapsed(at: now) == false)
        #expect(timer.hasElapsed(at: Date(timeIntervalSince1970: 1010)) == false)
        #expect(timer.hasElapsed(at: Date(timeIntervalSince1970: 2000)) == false)
    }

    @Test func hasElapsedFinishedAlwaysTrue() {
        let now = Date(timeIntervalSince1970: 1000)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .finished)

        #expect(timer.hasElapsed(at: now) == true)
        #expect(timer.hasElapsed(at: Date(timeIntervalSince1970: 2000)) == true)
    }

    // MARK: - paused(at:) transitions

    @Test func pausedRunningTransition() {
        let endDate = Date(timeIntervalSince1970: 1060)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .running(endDate: endDate))

        let pausedTimer = timer.paused(at: Date(timeIntervalSince1970: 1010))

        #expect(pausedTimer.id == timerID)
        #expect(pausedTimer.label == "Test Timer")
        if case .paused(let remaining) = pausedTimer.state {
            #expect(remaining == 50)
        } else {
            #expect(Bool(false), "Expected paused state")
        }
    }

    @Test func pausedRunningNoOpWhenAlreadyPaused() {
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .paused(remaining: 30))

        let result = timer.paused(at: Date(timeIntervalSince1970: 1010))

        #expect(result.id == timer.id)
        #expect(result.state == timer.state)
    }

    @Test func pausedRunningNoOpWhenFinished() {
        let now = Date(timeIntervalSince1970: 1000)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .finished)

        let result = timer.paused(at: now)

        #expect(result.id == timer.id)
        #expect(result.state == timer.state)
    }

    // MARK: - resumed(at:) transitions

    @Test func resumedPausedTransition() {
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .paused(remaining: 50))

        let resumedTimer = timer.resumed(at: Date(timeIntervalSince1970: 1010))

        #expect(resumedTimer.id == timerID)
        #expect(resumedTimer.label == "Test Timer")
        if case .running(let endDate) = resumedTimer.state {
            #expect(endDate == Date(timeIntervalSince1970: 1060))
        } else {
            #expect(Bool(false), "Expected running state")
        }
    }

    @Test func resumedRunningNoOpWhenAlreadyRunning() {
        let endDate = Date(timeIntervalSince1970: 1060)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .running(endDate: endDate))

        let result = timer.resumed(at: Date(timeIntervalSince1970: 1010))

        #expect(result.id == timer.id)
        #expect(result.state == timer.state)
    }

    @Test func resumedFinishedNoOp() {
        let now = Date(timeIntervalSince1970: 1000)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .finished)

        let result = timer.resumed(at: now)

        #expect(result.id == timer.id)
        #expect(result.state == timer.state)
    }

    // MARK: - finishedTimer() transition

    @Test func finishedTimerTransition() {
        let endDate = Date(timeIntervalSince1970: 1060)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .running(endDate: endDate))

        let finished = timer.finishedTimer()

        #expect(finished.id == timerID)
        #expect(finished.label == "Test Timer")
        #expect(finished.duration == 60)
        if case .finished = finished.state {
            // Expected
        } else {
            #expect(Bool(false), "Expected finished state")
        }
    }

    // MARK: - isRunning property

    @Test func isRunningTrueForRunningState() {
        let endDate = Date(timeIntervalSince1970: 1060)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .running(endDate: endDate))

        #expect(timer.isRunning == true)
    }

    @Test func isRunningFalseForPausedState() {
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .paused(remaining: 30))

        #expect(timer.isRunning == false)
    }

    @Test func isRunningFalseForFinishedState() {
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .finished)

        #expect(timer.isRunning == false)
    }

    // MARK: - Round-trip: pause/resume preserves remaining

    @Test func roundTripPauseResumePreservesRemaining() {
        let endDate = Date(timeIntervalSince1970: 1060)
        let timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .running(endDate: endDate))

        let pausedAt1010 = timer.paused(at: Date(timeIntervalSince1970: 1010))
        #expect(pausedAt1010.remaining(at: Date(timeIntervalSince1970: 1010)) == 50)

        let resumedAt2000 = pausedAt1010.resumed(at: Date(timeIntervalSince1970: 2000))
        #expect(resumedAt2000.remaining(at: Date(timeIntervalSince1970: 2000)) == 50)
        #expect(resumedAt2000.isRunning == true)
    }

    @Test func roundTripMultipleCyclesPreserveRemaining() {
        let endDate = Date(timeIntervalSince1970: 1060)
        var timer = CookTimer(id: timerID, label: "Test Timer", duration: 60, state: .running(endDate: endDate))

        // Pause at 1010, remaining = 50
        timer = timer.paused(at: Date(timeIntervalSince1970: 1010))
        #expect(timer.remaining(at: Date(timeIntervalSince1970: 1010)) == 50)

        // Resume at 1500, remaining should still be 50
        timer = timer.resumed(at: Date(timeIntervalSince1970: 1500))
        #expect(timer.remaining(at: Date(timeIntervalSince1970: 1500)) == 50)
        #expect(timer.isRunning == true)

        // Pause again at 1510, remaining = 40 (50 - 10)
        timer = timer.paused(at: Date(timeIntervalSince1970: 1510))
        #expect(timer.remaining(at: Date(timeIntervalSince1970: 1510)) == 40)

        // Resume at 3000, remaining should still be 40
        timer = timer.resumed(at: Date(timeIntervalSince1970: 3000))
        #expect(timer.remaining(at: Date(timeIntervalSince1970: 3000)) == 40)
    }
}
