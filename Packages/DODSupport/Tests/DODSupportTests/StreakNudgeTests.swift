import Foundation
import Testing

@testable import DODSupport

/// L1 coverage for the Streak Nudge feature (DUT-972).
@Suite("StreakNudge")
struct StreakNudgeTests {

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

    @Test func statusReturnsNoneWhenNoEntries() {
        let now = date(2026, 1, 21)  // Wednesday
        #expect(StreakNudge.status([], asOf: now, calendar: calendar) == .none)
    }

    @Test func statusReturnsSafeWhenCookedThisWeek() {
        let now = date(2026, 1, 21)  // Wednesday
        let entries = [
            entry(1, "R", at: date(2026, 1, 20))  // This week
        ]
        #expect(StreakNudge.status(entries, asOf: now, calendar: calendar) == .safe(streak: 1))
    }

    @Test func statusReturnsAtRiskWhenNoCookThisWeekButStreakExists() {
        let now = date(2026, 1, 21)  // Wednesday
        let entries = [
            entry(1, "R", at: date(2026, 1, 14))  // Last week
        ]
        #expect(StreakNudge.status(entries, asOf: now, calendar: calendar) == .atRisk(streak: 1))
    }

    @Test func statusReturnsAtRiskForMultiWeekStreakWhenNoCookThisWeek() {
        let now = date(2026, 1, 21)  // Wednesday
        let entries = [
            entry(1, "R", at: date(2026, 1, 14)),  // Last week
            entry(2, "R", at: date(2026, 1, 7)),  // Week before
        ]
        #expect(StreakNudge.status(entries, asOf: now, calendar: calendar) == .atRisk(streak: 2))
    }

    @Test func contentReturnsNilForSafeStatus() {
        let status = StreakNudge.Status.safe(streak: 2)
        #expect(StreakNudge.content(for: status) == nil)
    }

    @Test func contentReturnsContentForAtRiskStatus() {
        let status = StreakNudge.Status.atRisk(streak: 3)
        guard let content = StreakNudge.content(for: status) else {
            #expect(false, "Content should not be nil for atRisk status")
            return
        }
        #expect(content.title == "Your streak's alive 🔥")
        #expect(content.body == "3-week streak — one skillet dish keeps it going.")
        #expect(content.smallestNextRep == "Pick one easy skillet dish this week.")
    }

    @Test func contentReturnsNilForNoneStatus() {
        let status = StreakNudge.Status.none
        #expect(StreakNudge.content(for: status) == nil)
    }

    @Test func shouldSendReturnsTrueWhenNoLastSent() {
        #expect(StreakNudge.shouldSend(lastSent: nil, now: Date()) == true)
    }

    @Test func shouldSendReturnsFalseWithinInterval() {
        let now = Date()
        let lastSent = now.addingTimeInterval(-4 * 24 * 60 * 60)  // 4 days ago
        #expect(StreakNudge.shouldSend(lastSent: lastSent, now: now) == false)
    }

    @Test func shouldSendReturnsTrueAfterInterval() {
        let now = Date()
        let lastSent = now.addingTimeInterval(-6 * 24 * 60 * 60)  // 6 days ago
        #expect(StreakNudge.shouldSend(lastSent: lastSent, now: now) == true)
    }

    @Test func deepLinkIsCorrect() {
        #expect(StreakNudge.deepLink == "dod://feed")
    }
}
