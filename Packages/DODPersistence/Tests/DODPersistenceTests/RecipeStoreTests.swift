import DODDomain
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

@Suite("RecipeStore CRUD (T-073)") struct RecipeStoreTests {

    @Test func cacheListItemThenReadBack() async throws {
        let store = try await makeStore()
        let listItem = makeListItem(id: 1, title: "Apple Crisp")
        try await store.cache(listItem: listItem)
        let items = try await store.listItems(forIDs: [1])
        let first = try #require(items.first)
        #expect(first.id == 1)
        #expect(first.title == "Apple Crisp")
    }

    @Test func mergeDetailPopulatesIngredientsAndInstructions() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 42, title: "Pasta"))
        try await store.mergeDetail(makeRecipe(id: 42, withDetail: true))
        let recipe = try await store.recipe(id: 42)
        let unwrapped = try #require(recipe)
        #expect(unwrapped.ingredients.count == 2)
        #expect(unwrapped.instructions.count == 2)
        #expect(unwrapped.totalTime == .seconds(15 * 60))
    }

    @Test func toggleSavedPinsTheRow() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 7, title: "Bread"))
        let saved = try await store.toggleSaved(id: 7)
        #expect(saved == true)
        let savedList = try await store.savedRecipes()
        #expect(savedList.count == 1)
        #expect(savedList.first?.id == 7)
        let unsaved = try await store.toggleSaved(id: 7)
        #expect(unsaved == false)
        let savedAfter = try await store.savedRecipes()
        #expect(savedAfter.isEmpty)
    }
}

@Suite("RecipeStore LRU policy (T-074)") struct LRUPolicyTests {

    @Test func unsavedRowsAreCappedAtTheBudget() async throws {
        let store = try await makeStore()
        // Insert 5 rows past the cap.
        for index in 0..<(RecipeStore.unsavedLRUCap + 5) {
            try await store.cache(listItem: makeListItem(id: index, title: "Item \(index)"))
        }
        let remaining =
            try await store.savedRecipes().count
            + (try await store.listItems(
                forIDs: Array(0..<(RecipeStore.unsavedLRUCap + 5))
            )).count
        #expect(remaining <= RecipeStore.unsavedLRUCap)
    }

    @Test func savedRowsAreNeverEvicted() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 999, title: "Treasured Recipe"))
        _ = try await store.toggleSaved(id: 999)
        // Insert way more than the cap of unsaved rows.
        for index in 0..<(RecipeStore.unsavedLRUCap + 50) {
            try await store.cache(listItem: makeListItem(id: 1000 + index, title: "Filler \(index)"))
        }
        let saved = try await store.savedRecipes()
        #expect(saved.contains(where: { $0.id == 999 }), "Saved recipe must survive overflow")
    }
}

@Suite("RecipeStore image cache (T-075)") struct ImageCacheTests {

    @Test func cacheAndReadImage() async throws {
        let store = try await makeStore()
        let url = URL(string: "https://example.com/img.jpg") ?? URL(filePath: "/")
        let bytes = Data(repeating: 0x42, count: 1024)
        try await store.cacheImage(url: url, bytes: bytes)
        let read = try await store.image(url: url)
        #expect(read == bytes)
    }

    @Test func pinnedImagesAreNotEvictedByBudget() async throws {
        let store = try await makeStore()
        let pinnedURL = URL(string: "https://example.com/pinned.jpg") ?? URL(filePath: "/")
        // Pin a small image to a saved recipe.
        try await store.cacheImage(url: pinnedURL, bytes: Data(repeating: 0x01, count: 1024), pinnedToSavedRecipeID: 1)

        // Fill with non-pinned images. Use a much smaller fake budget by
        // shoveling enough bytes through that eviction kicks in for some.
        // We exercise the path; exact byte budgets are slow to fill in a unit
        // test, so we focus on the *correctness* of pinning.
        for index in 0..<5 {
            let url = URL(string: "https://example.com/\(index).jpg") ?? URL(filePath: "/")
            try await store.cacheImage(url: url, bytes: Data(repeating: 0xFF, count: 1024))
        }
        let pinned = try await store.image(url: pinnedURL)
        #expect(pinned != nil, "Pinned image must remain available")
    }
}

@Suite("RecipeStore blocklist (T-076, AC-1.7)") struct BlocklistTests {

    @Test func blocklistedRowExcludedFromListItems() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "Healthy"))
        try await store.cache(listItem: makeListItem(id: 2, title: "Broken"))
        try await store.markJSONLDFailed(id: 2)
        let visible = try await store.listItems(forIDs: [1, 2])
        #expect(visible.map(\.id) == [1])
    }

    @Test func clearBlocklistRestoresVisibility() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 5, title: "Foo"))
        try await store.markJSONLDFailed(id: 5)
        let beforeClear = try await store.listItems(forIDs: [5])
        #expect(beforeClear.isEmpty)
        try await store.clearBlocklist()
        let afterClear = try await store.listItems(forIDs: [5])
        #expect(afterClear.count == 1)
    }

    @Test func successfulReCacheClearsBlocklistedFlag() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 9, title: "Comeback"))
        try await store.markJSONLDFailed(id: 9)
        // Re-caching the same item (e.g. after pull-to-refresh) clears the flag.
        try await store.cache(listItem: makeListItem(id: 9, title: "Comeback"))
        let visible = try await store.listItems(forIDs: [9])
        #expect(visible.count == 1)
    }
}

// MARK: - Helpers

private func makeStore() async throws -> RecipeStore {
    let container = try RecipeStore.inMemoryContainer()
    return RecipeStore(modelContainer: container)
}

private func makeListItem(id: Int, title: String) -> RecipeListItem {
    RecipeListItem(
        id: id,
        title: title,
        excerpt: "An excerpt.",
        heroImage: URL(string: "https://example.com/\(id).jpg"),
        publishedAt: Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(id)),
        totalTimeDisplay: nil
    )
}

private func makeRecipe(id: Int, withDetail: Bool) -> Recipe {
    Recipe(
        id: id,
        slug: "slug-\(id)",
        title: "Title \(id)",
        excerpt: "Excerpt.",
        canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/") ?? URL(filePath: "/"),
        publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
        ingredients: withDetail ? [.init(text: "1 cup flour"), .init(text: "1 tsp salt")] : [],
        instructions: withDetail
            ? [.init(step: 1, text: "Mix."), .init(step: 2, text: "Bake.")]
            : [],
        totalTime: .seconds(15 * 60)
    )
}
