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

    /// DUT-346 — the app pins `firstWeekday` (Sunday) for the streak so the same
    /// cook history can't read as a different streak under a different device
    /// locale's week-start. With firstWeekday pinned, the streak is locale-stable.
    @Test func weeklyStreakIsLocaleStableWhenFirstWeekdayIsPinned() {
        func pinned(_ localeID: String) -> Calendar {
            var cal = Calendar(identifier: .gregorian)
            cal.firstWeekday = 1
            cal.timeZone = TimeZone(identifier: "UTC") ?? .current
            cal.locale = Locale(identifier: localeID)
            return cal
        }
        let now = date(2026, 1, 21)
        let entries = [
            entry(1, "R", at: date(2026, 1, 20)),
            entry(1, "R", at: date(2026, 1, 14)),
            entry(1, "R", at: date(2026, 1, 7)),
        ]
        let us = CookLogStats.currentWeeklyStreak(entries, asOf: now, calendar: pinned("en_US"))
        let fr = CookLogStats.currentWeeklyStreak(entries, asOf: now, calendar: pinned("fr_FR"))
        #expect(us == fr)
        #expect(us == 3)
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

    // MARK: - Rank ladder cook count (DUT-625 / DUT-685)

    private var dumpCakeID: Int { DumpCake.all[0].id }
    private var otherDumpCakeID: Int { DumpCake.all[1].id }

    /// A journal of N path cooks + M dump cakes counts N for the rank ladder,
    /// even though `totalCooks` counts N + M.
    @Test func rankLadderCountExcludesDumpCakes() {
        let pathIDs = [1001, 1002, 1003]  // none are dump cakes
        let entries =
            pathIDs.map { entry($0, "Path", at: date(2026, 1, 5)) }
            + [
                entry(dumpCakeID, "Dump", at: date(2026, 1, 6)),
                entry(otherDumpCakeID, "Dump", at: date(2026, 1, 7)),
                entry(dumpCakeID, "Dump", at: date(2026, 1, 8)),
            ]
        // 3 path + 3 dump cakes.
        #expect(CookLogStats.totalCooks(entries) == 6)
        #expect(CookLogStats.rankLadderCookCount(entries) == 3)
    }

    @Test func rankLadderCountEqualsTotalWhenNoDumpCakes() {
        let entries = [
            entry(1001, "Path", at: date(2026, 1, 5)),
            entry(1002, "Path", at: date(2026, 1, 6)),
        ]
        #expect(CookLogStats.rankLadderCookCount(entries) == CookLogStats.totalCooks(entries))
    }

    @Test func rankLadderCountIsZeroForOnlyDumpCakes() {
        let entries = DumpCake.all.map { entry($0.id, $0.title, at: date(2026, 1, 5)) }
        #expect(CookLogStats.totalCooks(entries) == DumpCake.all.count)
        #expect(CookLogStats.rankLadderCookCount(entries) == 0)
    }

    /// DUT-685 — the rank DISPLAY (derived from `rankLadderCookCount`) and the
    /// rank-up CELEBRATION (which counts the same path-only population) must never
    /// diverge for the same journal. A cook with 2 path + 3 dump cakes shows the
    /// Fire Starter rung (based on 2), not a higher rung it hasn't celebrated.
    @Test func rankDisplayMatchesCelebrationPopulation() {
        let entries = [
            entry(1001, "Path", at: date(2026, 1, 5)),
            entry(1002, "Path", at: date(2026, 1, 6)),
            entry(dumpCakeID, "Dump", at: date(2026, 1, 7)),
            entry(otherDumpCakeID, "Dump", at: date(2026, 1, 8)),
            entry(dumpCakeID, "Dump", at: date(2026, 1, 9)),
        ]
        let rankCooks = CookLogStats.rankLadderCookCount(entries)  // 2
        #expect(rankCooks == 2)
        // Display rank derives from the path-only count → Fire Starter (thr 1),
        // NOT Lid Lifter (thr 5) that the raw total (5) would show.
        let displayRank = CookProgression.currentRank(totalCooks: rankCooks)
        #expect(displayRank?.title == "Fire Starter")
        let totalRank = CookProgression.currentRank(totalCooks: CookLogStats.totalCooks(entries))
        #expect(totalRank?.title == "Lid Lifter")  // the OLD (wrong) display
        #expect(displayRank != totalRank)

        // The celebration for logging one more path cook fires the same population
        // the display now shows — climbing from 2 → 3 crosses the Coal Tender rung.
        let before = rankCooks
        let after = CookLogStats.rankLadderCookCount(
            entries + [entry(1003, "Path", at: date(2026, 1, 10))]
        )
        #expect(after == 3)
        #expect(CookProgression.rankUp(from: before, to: after)?.title == "Coal Tender")
    }

    // MARK: - Average rating / last-30-days (DUT-882 iOS parity)

    @Test func averageRatingIgnoresUnratedEntries() {
        let entries = [
            entry(1, "Bread", at: date(2026, 1, 5), rating: 5),
            entry(1, "Bread", at: date(2026, 1, 6), rating: 3),
            entry(2, "Chili", at: date(2026, 1, 7), rating: 4),
            entry(3, "Stew", at: date(2026, 1, 8)),  // unrated — must not count
            entry(3, "Stew", at: date(2026, 1, 9)),  // unrated — must not count
        ]
        // (5 + 3 + 4) / 3 rated entries = 4.0 — the 2 unrated entries are excluded,
        // not averaged in as zeros.
        #expect(CookLogStats.averageRating(entries) == 4.0)
    }

    @Test func averageRatingIsNilWhenNothingIsRated() {
        let entries = [
            entry(1, "Bread", at: date(2026, 1, 5)),
            entry(2, "Chili", at: date(2026, 1, 6)),
        ]
        #expect(CookLogStats.averageRating(entries) == nil)
        #expect(CookLogStats.averageRating([]) == nil)
    }

    @Test func cooksInLast30DaysCountsTheTrailingWindow() {
        let now = date(2026, 2, 4)
        let entries = [
            entry(1, "R", at: date(2026, 2, 4), rating: 5),  // today — counts
            entry(2, "R", at: date(2026, 1, 6)),  // exactly 29 days ago — counts
            entry(3, "R", at: date(2026, 1, 4)),  // 31 days ago — does NOT count
            entry(4, "R", at: date(2026, 1, 1)),  // well outside — does NOT count
        ]
        // 2 of the 4 entries fall inside the 30-day window (today + prior 29 days).
        #expect(CookLogStats.cooksInLast30Days(entries, asOf: now, calendar: calendar) == 2)
    }

    @Test func cooksInLast30DaysExcludesFutureDatedEntries() {
        let now = date(2026, 2, 4)
        let entries = [entry(1, "R", at: date(2026, 2, 5))]  // one day in the future
        #expect(CookLogStats.cooksInLast30Days(entries, asOf: now, calendar: calendar) == 0)
    }

    @Test func cooksInLast30DaysIsZeroForAnEmptyJournal() {
        #expect(CookLogStats.cooksInLast30Days([], asOf: date(2026, 2, 4), calendar: calendar) == 0)
    }
}
