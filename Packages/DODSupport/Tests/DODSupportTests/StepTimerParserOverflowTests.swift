import Foundation
import Testing

@testable import DODSupport

/// DUT-914 — `firstDuration(in:)` runs over untrusted JSON-LD step text. A
/// malformed 20+ digit quantity makes `quantity × unit.seconds` exceed
/// `Int.max`, and the old bare `Int(Double)` conversions trapped (SIGTRAP) —
/// crashing Cook Mode. Same class as `FractionRenderer`'s DUT-609/DUT-518.
/// The guard returns `nil` (no usable timer) instead of crashing, and leaves
/// every ordinary duration untouched.
@Suite("StepTimerParser Int-overflow guard (DUT-914)")
struct StepTimerParserOverflowTests {

    @Test func hugeDigitRunReturnsNilInsteadOfTrapping() {
        // 20-digit minutes: quantity × 60 blows past Int.max.
        #expect(StepTimerParser.firstDuration(in: "Bake 99999999999999999999 minutes") == nil)
    }

    @Test func hugeHourCountReturnsNilInsteadOfTrapping() {
        #expect(StepTimerParser.firstDuration(in: "Rest 100000000000000000 hours") == nil)
    }

    @Test func overflowingMixedFollowUpDoesNotCrashAndKeepsThePrimary() {
        // Valid primary ("1 hour") with an overflowing smaller-unit follow-up:
        // the follow-up contributes 0 rather than trapping, so the primary
        // survives as 3600s.
        #expect(
            StepTimerParser.firstDuration(in: "Cook 1 hour 99999999999999999999 minutes")
                == .seconds(3600)
        )
    }

    @Test func ordinaryDurationsAreUnchanged() {
        #expect(StepTimerParser.firstDuration(in: "Bake for 30 minutes") == .seconds(1800))
        #expect(StepTimerParser.firstDuration(in: "Simmer for 1 hour 30 minutes") == .seconds(5400))
        #expect(StepTimerParser.firstDuration(in: "Cook 1.5 hours") == .seconds(5400))
        #expect(StepTimerParser.firstDuration(in: "microwave 90 seconds") == .seconds(90))
    }
}
