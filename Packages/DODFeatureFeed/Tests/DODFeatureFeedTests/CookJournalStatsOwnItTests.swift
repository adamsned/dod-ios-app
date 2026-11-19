import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

@Suite("CookJournalStats Own It (DUT-974)")
struct CookJournalStatsOwnItTests {

    private func entry(_ recipeID: Int, _ title: String, at date: Date, rating: Int? = nil) -> CookLogEntry {
        CookLogEntry(id: UUID(), recipeID: recipeID, recipeTitle: title, cookedAt: date, personalRating: rating)
    }

    @Test func emptyCooksIsEmpty() {
        let stats = CookJournalView.computeStats([])
        #expect(stats.ownIt.isEmpty)
    }

    @Test func twoCooksOfRecipe1AndOneOfRecipe2() {
        let entries = [
            entry(1, "Bread", at: Date(timeIntervalSince1970: 0)),
            entry(1, "Bread", at: Date(timeIntervalSince1970: 86_400)),
            entry(2, "Cake", at: Date(timeIntervalSince1970: 172_800)),
        ]
        let stats = CookJournalView.computeStats(entries)
        #expect(stats.ownIt.map(\.recipeID) == [1, 2])
    }

    @Test func threeCooksOfRecipe1IsEmpty() {
        let entries = [
            entry(1, "Bread", at: Date(timeIntervalSince1970: 0)),
            entry(1, "Bread", at: Date(timeIntervalSince1970: 86_400)),
            entry(1, "Bread", at: Date(timeIntervalSince1970: 172_800)),
        ]
        let stats = CookJournalView.computeStats(entries)
        #expect(stats.ownIt.isEmpty)
    }

    @Test func captionWithTwoRemainingIsPlural() throws {
        let entries = [entry(1, "Bread", at: Date(timeIntervalSince1970: 0))]
        let progress = try #require(CookLogStats.ownItProgress(recipeID: 1, in: entries))
        #expect(progress.remaining == 2)
        #expect(CookJournalView.ownItCaption(progress) == "2 more cooks and this is yours")
    }

    @Test func captionWithOneRemainingIsSingular() throws {
        let entries = [
            entry(1, "Bread", at: Date(timeIntervalSince1970: 0)),
            entry(1, "Bread", at: Date(timeIntervalSince1970: 86_400)),
        ]
        let progress = try #require(CookLogStats.ownItProgress(recipeID: 1, in: entries))
        #expect(progress.remaining == 1)
        #expect(CookJournalView.ownItCaption(progress) == "1 more cook and this is yours")
    }
}
