import Foundation
import Testing

@testable import DODDomain

@Suite("MealPlanWeek")
struct MealPlanWeekTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    @Test func mealSlotRawValuesStable() {
        #expect(MealSlot.allCases.map(\.rawValue) == ["breakfast", "lunch", "dinner", "snack"])
    }

    @Test func weekStartIsMonday() {
        let cal = Self.calendar
        let monday = Self.date(2026, 10, 19)
        let wednesday = Self.date(2026, 10, 21)
        #expect(MealPlanWeek.weekStart(for: wednesday, calendar: cal) == monday)
        #expect(MealPlanWeek.weekStart(for: monday, calendar: cal) == monday)
    }

    @Test func daysReturnsSevenConsecutiveDays() {
        let cal = Self.calendar
        let start = Self.date(2026, 10, 19)
        let days = MealPlanWeek.days(inWeekStarting: start, calendar: cal)
        #expect(days.count == 7)
        guard let first = days.first, let last = days.last else {
            Issue.record("days was empty")
            return
        }
        let diff = cal.dateComponents([.day], from: first, to: last).day
        #expect(diff == 6)
    }

    @Test func pagingForwardAndBackRoundTrips() {
        let cal = Self.calendar
        let start = Self.date(2026, 10, 19)
        let forward = MealPlanWeek.weekStart(byAdding: 1, to: start, calendar: cal)
        #expect(forward == Self.date(2026, 10, 26))
        let back = MealPlanWeek.weekStart(byAdding: -1, to: forward, calendar: cal)
        #expect(back == start)
    }
}
