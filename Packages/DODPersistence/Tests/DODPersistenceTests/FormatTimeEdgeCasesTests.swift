import Foundation
import Testing

@testable import DODPersistence

/// DUT-373: Additional edge case coverage for `formatTime`. Tests boundary
/// conditions, large durations, and extreme negative values not covered by
/// the main FormatTimeTests suite.
@Suite("formatTime edge cases (DUT-373)")
struct FormatTimeEdgeCasesTests {

    @Test func largeDurationsWithHundredsOfHours() {
        #expect(formatTime(seconds: 360_000) == "100 hr")
        #expect(formatTime(seconds: 3_600_000) == "1000 hr")
    }

    @Test func singleDigitMinuteRemainder() {
        #expect(formatTime(seconds: 3660) == "1 hr 1 min")
        #expect(formatTime(seconds: 3720) == "1 hr 2 min")
        #expect(formatTime(seconds: 3900) == "1 hr 5 min")
    }

    @Test func nineMinuteRemainder() {
        #expect(formatTime(seconds: 3780) == "1 hr 3 min")
        #expect(formatTime(seconds: 5400) == "1 hr 30 min")
    }

    @Test func fiftyNineMinuteRemainder() {
        #expect(formatTime(seconds: 4140) == "1 hr 9 min")
        #expect(formatTime(seconds: 7140) == "1 hr 59 min")
    }

    @Test func multipleHoursWithSingleDigitRemainder() {
        #expect(formatTime(seconds: 7260) == "2 hr 1 min")
        #expect(formatTime(seconds: 10860) == "3 hr 1 min")
    }

    @Test func veryLargeNegativeValues() {
        #expect(formatTime(seconds: -360_000) == nil)
        #expect(formatTime(seconds: -1_000_000) == nil)
    }

    @Test func intMaxValueDoesNotOverflow() {
        let result = formatTime(seconds: Int.max)
        #expect(result != nil)
        #expect(result?.contains("hr") ?? false)
    }

    @Test func largeMinutesWithLargeRemainder() {
        #expect(formatTime(seconds: 215_940) == "59 hr 59 min")
    }

    @Test func roundTripsFromMinutesWithManyDigits() {
        #expect(formatTime(seconds: 18000) == "5 hr")
        #expect(formatTime(seconds: 18060) == "5 hr 1 min")
        #expect(formatTime(seconds: 18540) == "5 hr 9 min")
    }
}
