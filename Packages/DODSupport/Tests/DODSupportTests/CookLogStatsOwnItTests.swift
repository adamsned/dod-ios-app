import Foundation
import Testing

@testable import DODSupport

/// DUT-974 — "Own It" progress for a single recipe.
@Suite("CookLogStats Own It (DUT-974)")
struct CookLogStatsOwnItTests {

    private func entry(_ recipeID: Int, _ title: String, at date: Date, rating: Int? = nil) -> CookLogEntry {
        CookLogEntry(id: UUID(), recipeID: recipeID, recipeTitle: title, cookedAt: date, personalRating: rating)
    }

    private func cooks(_ count: Int, recipeID: Int = 1) -> [CookLogEntry] {
        (0..<count).map { index in
            entry(recipeID, "Bread", at: Date(timeIntervalSince1970: Double(index) * 86_400))
        }
    }

    @Test func neverCookedIsNil() {
        #expect(CookLogStats.ownItProgress(recipeID: 1, in: []) == nil)
        #expect(CookLogStats.ownItProgress(recipeID: 1, in: cooks(2, recipeID: 2)) == nil)
    }

    @Test func oneCookNeedsTwoMore() {
        let progress = CookLogStats.ownItProgress(recipeID: 1, in: cooks(1))
        #expect(progress?.timesCooked == 1)
        #expect(progress?.remaining == 2)
        #expect(progress?.isOwned == false)
    }

    @Test func threeCooksIsOwned() {
        let progress = CookLogStats.ownItProgress(recipeID: 1, in: cooks(3))
        #expect(progress?.remaining == 0)
        #expect(progress?.isOwned == true)
    }

    @Test func fiveCooksStaysAtZeroRemaining() {
        let progress = CookLogStats.ownItProgress(recipeID: 1, in: cooks(5))
        #expect(progress?.timesCooked == 5)
        #expect(progress?.remaining == 0)
        #expect(progress?.isOwned == true)
    }

    @Test func titleComesFromMostRecentCook() {
        let entries = [
            entry(1, "Old Name", at: Date(timeIntervalSince1970: 0)),
            entry(1, "New Name", at: Date(timeIntervalSince1970: 86_400)),
        ]
        #expect(CookLogStats.ownItProgress(recipeID: 1, in: entries)?.title == "New Name")
    }

    @Test func rotationEmptyIsEmpty() {
        #expect(CookLogStats.onYourWayToOwning([]).isEmpty)
    }

    @Test func rotationExcludesOwnedRecipes() {
        #expect(CookLogStats.onYourWayToOwning(cooks(3)).isEmpty)
    }

    @Test func rotationOrdersClosestToOwnedFirst() {
        let entries = cooks(1, recipeID: 2) + cooks(2, recipeID: 1)
        let result = CookLogStats.onYourWayToOwning(entries)
        #expect(result.map(\.recipeID) == [1, 2])
    }

    @Test func rotationHonorsLimit() {
        let entries = (1...5).flatMap { cooks(1, recipeID: $0) }
        #expect(CookLogStats.onYourWayToOwning(entries, limit: 3).count == 3)
    }

    @Test func rotationTieBreaksByMostRecentCook() {
        let entries = [
            entry(1, "Old", at: Date(timeIntervalSince1970: 0)),
            entry(2, "New", at: Date(timeIntervalSince1970: 86_400)),
        ]
        let result = CookLogStats.onYourWayToOwning(entries)
        #expect(result.map(\.recipeID) == [2, 1])
    }
}
