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

    /// DUT-495 — `start` stamps the timer's `recipeID` so a consumer sharing one
    /// engine across rungs (DUT-484) can scope its lookup to its own rung and
    /// never surface a bake started on a different rung.
    @Test func startStampsRecipeIDForCrossRungScoping() {
        let engine = makeEngine(TestClock())
        let rungA = engine.start(label: "A bake", duration: 60, recipeID: 683)
        let rungB = engine.start(label: "B bake", duration: 60, recipeID: 22294)
        #expect(rungA?.recipeID == 683)
        #expect(rungB?.recipeID == 22294)
        // A rung-683 consumer sees only its own running timer.
        let visibleToA = engine.timers.filter { $0.isRunning && $0.recipeID == 683 }
        #expect(visibleToA.map(\.label) == ["A bake"])
        // A default (nil-recipeID) start still works — no regression.
        #expect(engine.start(label: "Loose", duration: 30)?.recipeID == nil)
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

    /// DUT-210 — `onFinished` is a client closure that may re-enter the engine
    /// (`clearFinished`/`cancel`/`start`) and mutate `timers`. `refresh` must
    /// snapshot the finished timers and fire callbacks AFTER the loop, so a
    /// reentrant mutation can't invalidate the indices being iterated (trap /
    /// skipped completion). Two timers finish in the SAME tick and the callback
    /// re-enters on the FIRST one — the pre-fix code would index a mutated array
    /// on the second iteration.
    @Test func onFinishedFiringForEveryTimerSurvivesReentrantMutation() {
        let clock = TestClock()
        let engine = makeEngine(clock)
        var finishedLabels: [String] = []
        engine.onFinished = { timer in
            finishedLabels.append(timer.label)
            // Reentrant mutation of the live collection mid-completion: drop all
            // finished timers AND start a brand-new one. Under the pre-fix
            // mid-loop fire this corrupts iteration.
            engine.clearFinished()
            engine.start(label: "Reentrant-\(timer.label)", duration: 300)
        }
        engine.start(label: "First", duration: 60)
        engine.start(label: "Second", duration: 60)

        clock.advance(61)  // both elapse in the same tick
        engine.refresh()

        // Both completions fire exactly once — none trapped or skipped.
        #expect(finishedLabels.sorted() == ["First", "Second"])
        // The reentrant starts survived; the finished ones were cleared.
        #expect(engine.timers.map(\.label).sorted() == ["Reentrant-First", "Reentrant-Second"])
        #expect(engine.timers.allSatisfy { $0.isRunning })
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
