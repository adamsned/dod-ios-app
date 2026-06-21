import Foundation
import Testing

@testable import DODSupport

/// L1 coverage for the cook-journal statistics (US-48 / DUT-104) — the numbers
/// the habit features (streak/badges/Wrapped) read. A fixed UTC, Monday-first
/// calendar + fixed dates make every value deterministic.
@Suite("CookLogStats (DUT-104)")
struct CookLogStatsTests {

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

    @Test func totalAndTimesCooked() {
        let entries = [
            entry(1, "Bread", at: date(2026, 1, 5)),
            entry(1, "Bread", at: date(2026, 1, 12)),
            entry(2, "Chili", at: date(2026, 1, 13)),
        ]
        #expect(CookLogStats.totalCooks(entries) == 3)
        #expect(CookLogStats.timesCooked(recipeID: 1, in: entries) == 2)
        #expect(CookLogStats.timesCooked(recipeID: 2, in: entries) == 1)
        #expect(CookLogStats.timesCooked(recipeID: 99, in: entries) == 0)
    }

    @Test func mostCookedPicksHighestCount() {
        let entries = [
            entry(1, "Bread", at: date(2026, 1, 5)),
            entry(1, "Bread", at: date(2026, 1, 12)),
            entry(1, "Bread", at: date(2026, 1, 19)),
            entry(2, "Chili", at: date(2026, 1, 13)),
            entry(2, "Chili", at: date(2026, 1, 20)),
        ]
        let top = CookLogStats.mostCooked(entries)
        #expect(top?.recipeID == 1)
        #expect(top?.title == "Bread")
        #expect(top?.count == 3)
        #expect(CookLogStats.mostCooked([]) == nil)
    }

    @Test func mostCookedTieBreaksToMoreRecent() {
        // Both cooked twice; recipe 2's last cook is later → it wins.
        let entries = [
            entry(1, "Bread", at: date(2026, 1, 5)),
            entry(1, "Bread", at: date(2026, 1, 6)),
            entry(2, "Chili", at: date(2026, 1, 7)),
            entry(2, "Chili", at: date(2026, 1, 20)),
        ]
        #expect(CookLogStats.mostCooked(entries)?.recipeID == 2)
    }

    @Test func weeklyStreakCountsConsecutiveWeeks() {
        let now = date(2026, 1, 21)  // Wed; week starts Mon Jan 19
        let entries = [
            entry(1, "R", at: date(2026, 1, 20)),  // this week
            entry(1, "R", at: date(2026, 1, 14)),  // last week (Mon Jan 12)
            entry(1, "R", at: date(2026, 1, 7)),  // week before (Mon Jan 5)
        ]
        #expect(CookLogStats.currentWeeklyStreak(entries, asOf: now, calendar: calendar) == 3)
    }

    @Test func weeklyStreakBreaksOnAGap() {
        let now = date(2026, 1, 21)
        let entries = [
            entry(1, "R", at: date(2026, 1, 20)),  // this week
            // no cook the week of Jan 12 → gap
            entry(1, "R", at: date(2026, 1, 7)),  // two weeks ago
        ]
        #expect(CookLogStats.currentWeeklyStreak(entries, asOf: now, calendar: calendar) == 1)
    }

    @Test func weeklyStreakGivesGraceForAnEmptyInProgressWeek() {
        let now = date(2026, 1, 21)  // current week (Jan 19) has NO cook yet
        let entries = [
            entry(1, "R", at: date(2026, 1, 14)),  // last week
            entry(1, "R", at: date(2026, 1, 7)),  // week before
        ]
        // Grace: the empty in-progress week doesn't zero the streak — anchored at last week.
        #expect(CookLogStats.currentWeeklyStreak(entries, asOf: now, calendar: calendar) == 2)
    }

    @Test func weeklyStreakIsZeroWhenColdForTwoWeeks() {
        let now = date(2026, 1, 21)
        let entries = [entry(1, "R", at: date(2026, 1, 1))]  // 3 weeks ago
        #expect(CookLogStats.currentWeeklyStreak(entries, asOf: now, calendar: calendar) == 0)
        #expect(CookLogStats.currentWeeklyStreak([], asOf: now, calendar: calendar) == 0)
    }

    @Test func busiestMonthPicksTheHeaviestMonth() {
        let entries = [
            entry(1, "R", at: date(2026, 1, 5)),
            entry(1, "R", at: date(2026, 1, 12)),
            entry(2, "R", at: date(2026, 1, 20)),
            entry(3, "R", at: date(2026, 2, 2)),
            entry(3, "R", at: date(2026, 2, 9)),
        ]
        let busiest = CookLogStats.busiestMonth(entries, calendar: calendar)
        #expect(busiest?.year == 2026)
        #expect(busiest?.month == 1)
        #expect(busiest?.count == 3)
        #expect(CookLogStats.busiestMonth([], calendar: calendar) == nil)
    }

    @Test func personalRatingIsClampedToOneThroughFive() {
        #expect(entry(1, "R", at: date(2026, 1, 1), rating: 9).personalRating == 5)
        #expect(entry(1, "R", at: date(2026, 1, 1), rating: 0).personalRating == 1)
        #expect(entry(1, "R", at: date(2026, 1, 1), rating: 3).personalRating == 3)
        #expect(entry(1, "R", at: date(2026, 1, 1)).personalRating == nil)
    }
}
