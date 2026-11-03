import Foundation
import Testing

@testable import DODSupport

@Suite("CookStreakWidgetSnapshot") struct CookStreakWidgetSnapshotTests {

    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return cal
    }()

    /// November 2026 at the given day and hour (UTC). 2026-11-04 is a Wednesday.
    static func date(_ day: Int, hour: Int = 12) -> Date {
        let comps = DateComponents(year: 2026, month: 11, day: day, hour: hour)
        return calendar.date(from: comps) ?? Date(timeIntervalSince1970: 0)
    }

    @Test func emptyStatsHaveSevenFalseDots() {
        #expect(CookStreakStats.empty.weekDots == Array(repeating: false, count: 7))
        #expect(CookStreakStats.empty.streakDays == 0)
        #expect(CookStreakStats.empty.hasAnyCooks == false)
    }

    @Test func streakCountsConsecutiveDaysEndingToday() {
        let cal = Self.calendar
        let days = Set([2, 3, 4].map { cal.startOfDay(for: Self.date($0)) })
        let result = CookStreakStats.streak(days: days, now: Self.date(4, hour: 20), calendar: cal)
        #expect(result == 3)
    }
}
