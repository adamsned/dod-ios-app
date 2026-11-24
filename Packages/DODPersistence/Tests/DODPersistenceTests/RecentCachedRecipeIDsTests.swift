import DODDomain
import Foundation
import Testing

@testable import DODPersistence

@Suite("RecipeStore.recentCachedRecipeIDs (DUT-1027)")
struct RecentCachedRecipeIDsTests {

    private func recipe(id: Int, publishedOffset: TimeInterval) -> Recipe {
        Recipe(
            id: id,
            slug: "slug-\(id)",
            title: "Title \(id)",
            excerpt: "Excerpt.",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000 + publishedOffset),
            ingredients: []
        )
    }

    @Test func emptyCacheReturnsEmpty() async throws {
        let store = try await makeStore()
        #expect(try await store.recentCachedRecipeIDs(limit: 5).isEmpty)
    }

    @Test func nonPositiveLimitReturnsEmpty() async throws {
        let store = try await makeStore()
        try await store.mergeDetail(recipe(id: 1, publishedOffset: 0))
        #expect(try await store.recentCachedRecipeIDs(limit: 0).isEmpty)
    }

    @Test func returnsNewestFirstCappedAtLimit() async throws {
        let store = try await makeStore()
        try await store.mergeDetail(recipe(id: 1, publishedOffset: 10))
        try await store.mergeDetail(recipe(id: 2, publishedOffset: 30))
        try await store.mergeDetail(recipe(id: 3, publishedOffset: 20))
        #expect(try await store.recentCachedRecipeIDs(limit: 2) == [2, 3])
        #expect(try await store.recentCachedRecipeIDs(limit: 10) == [2, 3, 1])
    }
}
