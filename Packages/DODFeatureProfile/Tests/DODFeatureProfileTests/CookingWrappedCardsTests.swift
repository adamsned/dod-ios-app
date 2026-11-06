import DODSupport
import Foundation
import Testing

@testable import DODFeatureProfile

@Suite struct CookingWrappedCardsTests {
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        cal.locale = Locale(identifier: "en_US")
        return cal
    }()

    static func entry(recipeID: Int = 1, month: Int = 1, day: Int = 1) -> CookLogEntry {
        let date =
            calendar.date(
                from: DateComponents(year: 2026, month: month, day: day, hour: 12)
            ) ?? Date(timeIntervalSince1970: 0)
        return CookLogEntry(
            id: UUID(),
            recipeID: recipeID,
            recipeTitle: "Recipe \(recipeID)",
            cookedAt: date
        )
    }

    static func wrapped(_ entries: [CookLogEntry]) -> CookingWrapped {
        CookingWrapped.make(
            entries: entries,
            period: .calendarYear(2026),
            categoryByRecipeID: [:],
            calendar: calendar
        )
    }

    @Test func zeroCooksShowsSingleEncouragingCard() {
        let cards = CookingWrappedCards.cards(for: Self.wrapped([]), calendar: Self.calendar)
        #expect(cards.count == 1)
        #expect(cards.first?.id == "low-data")
        #expect(cards.first?.headline == "Your cooking story starts here")
    }

    @Test func twoCooksIsStillLowData() {
        let entries = [Self.entry(day: 1), Self.entry(day: 2)]
        let cards = CookingWrappedCards.cards(for: Self.wrapped(entries), calendar: Self.calendar)
        #expect(cards.count == 1)
        #expect(cards.first?.id == "low-data")
    }
}
