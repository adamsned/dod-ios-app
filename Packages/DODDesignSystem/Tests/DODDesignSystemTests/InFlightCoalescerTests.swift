import Foundation
import Testing

@testable import DODDesignSystem

/// DUT-516: two visible cells with the same hero URL (or a cell reappearing
/// mid-load) must share ONE underlying fetch instead of each issuing a separate
/// request. The coalescing map is extracted as a UIKit-free generic type so the
/// "N concurrent same-key calls → exactly one run" invariant is testable on the
/// macOS test slice, independent of the UIKit-coupled loader.
@Suite("InFlightCoalescer (DUT-516)")
struct InFlightCoalescerTests {

    /// A `Sendable` counter the coalesced `run` closure bumps once per actual run.
    private actor RunCounter {
        private(set) var count = 0
        func bump() { count += 1 }
    }

    @Test func concurrentSameKeyCallsShareOneRun() async {
        let coalescer = InFlightCoalescer<String, Int>()
        let counter = RunCounter()
        // A continuation lets us hold the single in-flight run open until every
        // concurrent caller has coalesced onto it, so the assertion is
        // deterministic rather than a timing race.
        let gate = Gate()

        async let first = coalescer.value(for: "url") {
            await counter.bump()
            await gate.wait()
            return 42
        }
        async let second = coalescer.value(for: "url") {
            await counter.bump()
            await gate.wait()
            return 42
        }
        async let third = coalescer.value(for: "url") {
            await counter.bump()
            await gate.wait()
            return 42
        }

        // Give the three calls a moment to all coalesce onto the first task,
        // then release the run.
        await Task.yield()
        await gate.open()

        let results = await [first, second, third]
        #expect(results == [42, 42, 42], "all callers get the shared value")
        #expect(await counter.count == 1, "the closure ran exactly once for the shared key")
        #expect(await coalescer.inFlightCount == 0, "the slot is cleared after completion")
    }

    @Test func differentKeysRunIndependently() async {
        let coalescer = InFlightCoalescer<String, Int>()
        let counter = RunCounter()

        async let first = coalescer.value(for: "a") {
            await counter.bump()
            return 1
        }
        async let second = coalescer.value(for: "b") {
            await counter.bump()
            return 2
        }
        _ = await [first, second]
        #expect(await counter.count == 2, "distinct keys each run their own closure")
    }

    @Test func aSecondCallAfterCompletionRunsAgain() async {
        // Identity-checked cleanup: once a key's task completes and its slot is
        // cleared, a later call for the same key starts a fresh run (the map is
        // an IN-FLIGHT coalescer, not a result cache).
        let coalescer = InFlightCoalescer<String, Int>()
        let counter = RunCounter()

        _ = await coalescer.value(for: "url") {
            await counter.bump()
            return 7
        }
        _ = await coalescer.value(for: "url") {
            await counter.bump()
            return 7
        }
        #expect(await counter.count == 2, "a call after the first completed re-runs")
    }

    /// A minimal one-shot gate: `wait()` suspends until `open()` is called.
    private actor Gate {
        private var waiters: [CheckedContinuation<Void, Never>] = []
        private var opened = false

        func wait() async {
            if opened { return }
            await withCheckedContinuation { waiters.append($0) }
        }

        func open() {
            opened = true
            for waiter in waiters { waiter.resume() }
            waiters.removeAll()
        }
    }
}
