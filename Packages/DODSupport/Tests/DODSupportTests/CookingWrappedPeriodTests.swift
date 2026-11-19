import Foundation
import Testing

@testable import DODSupport

@Suite("CookingWrappedPeriod (DUT-177)")
struct CookingWrappedPeriodTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private func entry(_ recipeID: Int, _ title: String, at date: Date) -> CookLogEntry {
        CookLogEntry(id: UUID(), recipeID: recipeID, recipeTitle: title, cookedAt: date)
    }

    @Test func calendarYearIncludesJan1AndExcludesNextJan1() {
        let entries = [
            entry(1, "A", at: date(2025, 12, 31)),
            entry(2, "B", at: date(2026, 1, 1)),
            entry(3, "C", at: date(2026, 12, 31)),
            entry(4, "D", at: date(2027, 1, 1)),
        ]
        let kept = CookingWrappedPeriod.calendarYear(2026).filter(entries, calendar: calendar)
        #expect(kept.map(\.recipeID) == [2, 3])
    }

    @Test func yearSoFarStopsAtToday() {
        let entries = [
            entry(1, "A", at: date(2026, 6, 10)),
            entry(2, "B", at: date(2026, 6, 11)),
        ]
        let period = CookingWrappedPeriod.yearSoFar(asOf: date(2026, 6, 10))
        let kept = period.filter(entries, calendar: calendar)
        #expect(kept.map(\.recipeID) == [1])
    }
}
