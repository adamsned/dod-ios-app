import Foundation
import Testing

@testable import DODPersistence

@Suite("RecipeStore recentCachedRecipeIDs (DUT-1027)")
struct RecipeStoreRecentIDsTests {
    @Test func returnsNewestFirstCappedAtLimit() async throws {
        let store = try await makeStore()
        try await store.cache(listItems: (1...5).map { makeListItem(id: $0, title: "R\($0)") })
        #expect(try await store.recentCachedRecipeIDs(limit: 3) == [5, 4, 3])
    }

    @Test func emptyCacheAndZeroLimitReturnEmpty() async throws {
        let store = try await makeStore()
        #expect(try await store.recentCachedRecipeIDs(limit: 10).isEmpty)
        #expect(try await store.recentCachedRecipeIDs(limit: 0).isEmpty)
    }
}
