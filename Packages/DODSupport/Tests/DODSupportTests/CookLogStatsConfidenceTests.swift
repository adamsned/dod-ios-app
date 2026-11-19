import Foundation
import Testing

@testable import DODSupport

@Suite("CookLogStats Confidence (DUT-975)")
struct CookLogStatsConfidenceTests {

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

    private func entry(_ recipeID: Int, _ title: String, at date: Date, confidence: Int?) -> CookLogEntry {
        CookLogEntry(id: UUID(), recipeID: recipeID, recipeTitle: title, cookedAt: date, confidence: confidence)
    }

    @Test func trajectoryIsChronologicalAndSkipsNil() {
        let entries = [
            entry(1, "Bread", at: date(2026, 1, 5), confidence: nil),
            entry(1, "Bread", at: date(2026, 1, 12), confidence: 3),
            entry(2, "Chili", at: date(2026, 1, 13), confidence: 5),
            entry(2, "Chili", at: date(2026, 1, 19), confidence: nil),
        ]

        let trajectory = CookLogStats.confidenceTrajectory(entries)
        #expect(trajectory.count == 2)  // Only 2 entries with confidence
        #expect(trajectory[0].date == date(2026, 1, 12))  // First chronological entry
        #expect(trajectory[0].confidence == 3)
        #expect(trajectory[1].date == date(2026, 1, 13))  // Second chronological entry
        #expect(trajectory[1].confidence == 5)
    }

    @Test func trendNilBelowFourReads() {
        let entries = [
            entry(1, "Bread", at: date(2026, 1, 5), confidence: 1),
            entry(1, "Bread", at: date(2026, 1, 12), confidence: 2),
            entry(2, "Chili", at: date(2026, 1, 13), confidence: 3),
        ]

        #expect(CookLogStats.confidenceTrend(entries) == nil)
    }

    @Test func trendPositiveWhenConfidenceRises() {
        let entries = [
            entry(1, "Bread", at: date(2026, 1, 5), confidence: 1),
            entry(1, "Bread", at: date(2026, 1, 12), confidence: 2),
            entry(2, "Chili", at: date(2026, 1, 13), confidence: 2),
            entry(2, "Chili", at: date(2026, 1, 19), confidence: 4),
            entry(3, "Stew", at: date(2026, 1, 20), confidence: 5),
            entry(3, "Stew", at: date(2026, 1, 21), confidence: 5),
        ]

        // early = (1 + 2 + 2) / 3 = 5/3
        // recent = (4 + 5 + 5) / 3 = 14/3
        // trend = 14/3 - 5/3 = 9/3 = 3.0
        #expect(CookLogStats.confidenceTrend(entries) == 3.0)
    }
}
