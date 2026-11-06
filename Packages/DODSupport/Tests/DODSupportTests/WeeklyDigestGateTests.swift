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

    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.gmt
        return calendar
    }

    /// A UTC date on 2026-03-`day` at `hour`:00.
    private static func date(day: Int, hour: Int) -> Date {
        let parts = DateComponents(year: 2026, month: 3, day: day, hour: hour)
        return utc.date(from: parts) ?? .distantPast
    }

    @Test func zeroNewRecipesNeverSends() {
        let now = Self.date(day: 20, hour: 10)
        #expect(
            !WeeklyDigestGate.shouldSend(
                newRecipeCount: 0,
                lastSentAt: nil,
                now: now,
                calendar: Self.utc
            )
        )
    }
}
