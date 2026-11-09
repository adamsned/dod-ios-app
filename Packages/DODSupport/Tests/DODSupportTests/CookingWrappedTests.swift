import Foundation
import Testing

@testable import DODSupport

@Suite("CookingWrapped (DUT-177)")
struct CookingWrappedTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 2  // Monday
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private func entry(_ recipeID: Int, _ title: String, at date: Date, rating: Int? = nil) -> CookLogEntry {
        CookLogEntry(id: UUID(), recipeID: recipeID, recipeTitle: title, cookedAt: date, personalRating: rating)
    }

    @Test func emptyLogGivesZeroes() {
        let result = CookingWrapped.make(
            entries: [],
            period: .calendarYear(2026),
            categoryByRecipeID: [:],
            calendar: calendar
        )
        #expect(result.totalCooks == 0)
        #expect(result.mostCooked == nil)
        #expect(result.topCategory == nil)
        #expect(result.newRecipesTried == 0)
        #expect(result.busiestMonth == nil)
    }

    @Test func countsOnlyPeriodEntries() {
        let entries = [
            entry(1, "A", at: date(2026, 1, 5)),
            entry(2, "B", at: date(2026, 1, 6)),
            entry(3, "C", at: date(2025, 1, 5)),  // Before period
        ]
        let result = CookingWrapped.make(
            entries: entries,
            period: .calendarYear(2026),
            categoryByRecipeID: [:],
            calendar: calendar
        )
        #expect(result.totalCooks == 2)
    }

    @Test func newRecipesExcludeThoseCookedBefore() {
        let entries = [
            entry(1, "A", at: date(2025, 1, 5)),  // Before period
            entry(2, "B", at: date(2025, 1, 6)),  // Before period
            entry(1, "A", at: date(2026, 1, 5)),  // During period
            entry(2, "B", at: date(2026, 1, 6)),  // During period
        ]
        let result = CookingWrapped.make(
            entries: entries,
            period: .calendarYear(2026),
            categoryByRecipeID: [:],
            calendar: calendar
        )
        #expect(result.newRecipesTried == 0)
    }

    @Test func topCategoryPicksMostCooked() {
        let entries = [
            entry(1, "A", at: date(2026, 1, 5)),
            entry(2, "B", at: date(2026, 1, 6)),
        ]
        let categoryByRecipeID = [1: "Desserts", 2: "Mains"]
        let result = CookingWrapped.make(
            entries: entries,
            period: .calendarYear(2026),
            categoryByRecipeID: categoryByRecipeID,
            calendar: calendar
        )
        #expect(result.topCategory == "Mains")
    }

    @Test func busiestMonthAndMostCookedPassThrough() {
        let entries = [
            entry(1, "A", at: date(2026, 3, 5)),
            entry(1, "A", at: date(2026, 3, 6)),
            entry(1, "A", at: date(2026, 3, 7)),
        ]
        let result = CookingWrapped.make(
            entries: entries,
            period: .calendarYear(2026),
            categoryByRecipeID: [:],
            calendar: calendar
        )
        #expect(result.mostCooked?.count == 3)
        #expect(result.busiestMonth?.month == 3)
    }
}
