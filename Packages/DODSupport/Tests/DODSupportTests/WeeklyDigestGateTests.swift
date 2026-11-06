import Foundation
import Testing

@testable import DODSupport

/// DUT-152 — `WeeklyDigestGate` decides whether the opt-in weekly digest may send.
@Suite("WeeklyDigestGateTests")
struct WeeklyDigestGateTests {

    @Test func isQuietHourBoundaries() {
        #expect(WeeklyDigestGate.isQuietHour(7))
        #expect(!WeeklyDigestGate.isQuietHour(8))
        #expect(!WeeklyDigestGate.isQuietHour(20))
        #expect(WeeklyDigestGate.isQuietHour(21))
    }
}
