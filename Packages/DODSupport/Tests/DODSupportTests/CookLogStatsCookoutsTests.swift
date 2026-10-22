import Foundation
import Testing

@testable import DODSupport

@Suite("CookLogStats cookouts (DUT-976)")
struct CookLogStatsCookoutsTests {

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

    @Test func averageRatingIgnoresUnrated() {
        let group = CookoutGroup(
            day: date(2026, 1, 4),
            entries: [entry(1, "A", at: date(2026, 1, 4), rating: 4), entry(2, "B", at: date(2026, 1, 4), rating: nil)]
        )
        #expect(group.averageRating == 4.0)
        #expect(group.dishCount == 2)
    }
}
