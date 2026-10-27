import Foundation
import Testing

@testable import DODSupport

@Suite("NextRungSignals") struct NextRungSignalsTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return cal
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func entry(recipeID: Int, daysAgo: Int, rating: Int?) -> CookLogEntry {
        CookLogEntry(
            id: UUID(),
            recipeID: recipeID,
            recipeTitle: "Recipe \(recipeID)",
            cookedAt: now.addingTimeInterval(-Double(daysAgo) * 86_400),
            personalRating: rating
        )
    }

    @Test func emptyEntriesGiveNoHistory() {
        let signals = NextRungSignals.make(entries: [], asOf: now, calendar: calendar)
        #expect(signals.totalCooks == 0)
        #expect(signals.daysSinceLastCook == nil)
        #expect(signals.lastRating == nil)
        #expect(signals.lastCookedRecipeID == nil)
    }

    @Test func latestCookDrivesRecencyAndRating() {
        let entries = [
            entry(recipeID: 10, daysAgo: 90, rating: 5),
            entry(recipeID: 20, daysAgo: 30, rating: 2),
        ]
        let signals = NextRungSignals.make(entries: entries, asOf: now, calendar: calendar)
        #expect(signals.daysSinceLastCook == 30)
        #expect(signals.lastRating == 2)
        #expect(signals.lastCookedRecipeID == 20)
        #expect(signals.cookedRecipeIDs == [10, 20])
    }

    @Test func cooksToNextRankMatchesProgression() {
        let entries = [entry(recipeID: 1, daysAgo: 1, rating: nil)]
        let signals = NextRungSignals.make(entries: entries, asOf: now, calendar: calendar)
        #expect(signals.cooksToNextRank == CookProgression.cooksToNextRank(totalCooks: signals.totalCooks))
    }
}
