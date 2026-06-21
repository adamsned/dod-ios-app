import Foundation
import Testing

@testable import DODSupport

/// L1 coverage for the cooking-timer engine (US-47 / DUT-100). A controllable
/// clock drives every transition deterministically — no real waiting.
@MainActor
@Suite("CookTimerEngine (DUT-100)")
struct CookTimerEngineTests {

    /// Mutable wall clock for the engine under test.
    private final class TestClock: @unchecked Sendable {
        var now: Date
        init(_ start: Date = Date(timeIntervalSince1970: 1_000)) { now = start }
        func advance(_ seconds: TimeInterval) { now += seconds }
        var read: () -> Date { { [self] in now } }
    }

    private func makeEngine(_ clock: TestClock) -> CookTimerEngine {
        CookTimerEngine(clock: clock.read)
    }

    @Test func startCreatesARunningTimerWithFullRemaining() {
        let clock = TestClock()
        let engine = makeEngine(clock)
        let timer = engine.start(label: "Bake", duration: 60)
        #expect(timer != nil)
        #expect(engine.timers.count == 1)
        #expect(engine.timers[0].isRunning)
        #expect(engine.timers[0].remaining(at: clock.now) == 60)
        #expect(engine.timers[0].label == "Bake")
    }

    @Test func startRejectsNonPositiveDuration() {
        let engine = makeEngine(TestClock())
        #expect(engine.start(label: "Nope", duration: 0) == nil)
        #expect(engine.start(label: "Nope", duration: -5) == nil)
        #expect(engine.timers.isEmpty)
    }

    @Test func remainingCountsDownAsTheClockAdvances() {
        let clock = TestClock()
        let engine = makeEngine(clock)
        engine.start(label: "Simmer", duration: 100)
        clock.advance(30)
        #expect(engine.timers[0].remaining(at: clock.now) == 70)
        clock.advance(80)  // past the end
        #expect(engine.timers[0].remaining(at: clock.now) == 0)  // clamped, not negative
    }

    @Test func pauseFreezesRemainingAndResumeReAnchors() throws {
        let clock = TestClock()
        let engine = makeEngine(clock)
        let timer = try #require(engine.start(label: "Proof", duration: 600))
        clock.advance(200)  // 400 left
        engine.pause(timer.id)
        #expect(engine.timers[0].isRunning == false)
        // Time passes while paused — remaining must NOT change.
        clock.advance(1_000)
        #expect(engine.timers[0].remaining(at: clock.now) == 400)
        // Resume: the timer now has 400s from the current clock.
        engine.resume(timer.id)
        #expect(engine.timers[0].isRunning)
        clock.advance(150)
        #expect(engine.timers[0].remaining(at: clock.now) == 250)
    }

    @Test func refreshFinishesElapsedTimersAndFiresOnFinishedOnce() {
        let clock = TestClock()
        let engine = makeEngine(clock)
        var finishedLabels: [String] = []
        engine.onFinished = { finishedLabels.append($0.label) }
        engine.start(label: "Toast", duration: 60)

        clock.advance(30)
        engine.refresh()  // not elapsed yet
        #expect(engine.timers[0].isRunning)
        #expect(finishedLabels.isEmpty)

        clock.advance(40)  // total 70 > 60
        engine.refresh()
        #expect(engine.timers[0].state == .finished)
        #expect(finishedLabels == ["Toast"])

        // Idempotent — a second refresh does NOT re-fire.
        engine.refresh()
        #expect(finishedLabels == ["Toast"])
    }

    @Test func soonestFinishingPicksTheNearestRunningTimer() {
        let clock = TestClock()
        let engine = makeEngine(clock)
        engine.start(label: "Long", duration: 600)
        engine.start(label: "Short", duration: 120)
        engine.start(label: "Medium", duration: 300)
        #expect(engine.soonestFinishing?.label == "Short")
        // Once the short one finishes, it's no longer "running" → Medium wins.
        clock.advance(121)
        engine.refresh()
        #expect(engine.soonestFinishing?.label == "Medium")
    }

    @Test func cancelRemovesAndClearFinishedDropsDoneTimers() throws {
        let clock = TestClock()
        let engine = makeEngine(clock)
        let timerA = try #require(engine.start(label: "A", duration: 60))
        engine.start(label: "B", duration: 600)
        engine.cancel(timerA.id)
        #expect(engine.timers.map(\.label) == ["B"])

        engine.start(label: "C", duration: 10)
        clock.advance(11)
        engine.refresh()  // C finishes
        #expect(engine.timers.contains { $0.state == .finished })
        engine.clearFinished()
        #expect(engine.timers.allSatisfy { $0.state != .finished })
        #expect(engine.timers.map(\.label) == ["B"])
    }

    @Test func hasActiveTimersReflectsRunningState() {
        let clock = TestClock()
        let engine = makeEngine(clock)
        #expect(engine.hasActiveTimers == false)
        engine.start(label: "X", duration: 5)
        #expect(engine.hasActiveTimers)
        clock.advance(6)
        engine.refresh()
        #expect(engine.hasActiveTimers == false)  // finished, not active
    }
}
