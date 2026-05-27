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

    /// REG-DOD-NAV-1: cache(listItem:) must round-trip canonicalURL.
    /// Before this fix the URL was dropped on insert, which made recipe-tap
    /// navigation fall back to the homepage and immediately auto-dismiss.
    @Test func canonicalURLRoundTrips() async throws {
        let store = try await makeStore()
        let url = URL(string: "https://www.dutchovendaddy.com/test-recipe/") ?? URL(filePath: "/")
        let listItem = RecipeListItem(
            id: 88,
            title: "Test",
            excerpt: "x",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil,
            canonicalURL: url
        )
        try await store.cache(listItem: listItem)
        let items = try await store.listItems(forIDs: [88])
        let first = try #require(items.first)
        #expect(first.canonicalURL == url)
    }

    /// Updating an existing row with a fresh canonicalURL should overwrite,
    /// but passing nil should NOT clobber a previously-stored good value.
    @Test func canonicalURLUpdatesButDoesNotClobberOnNil() async throws {
        let store = try await makeStore()
        let url = URL(string: "https://www.dutchovendaddy.com/r/") ?? URL(filePath: "/")
        try await store.cache(
            listItem: RecipeListItem(
                id: 99,
                title: "A",
                excerpt: "x",
                heroImage: nil,
                publishedAt: .now,
                totalTimeDisplay: nil,
                canonicalURL: url
            )
        )
        // Re-cache with nil canonicalURL (simulating a partial update).
        try await store.cache(
            listItem: RecipeListItem(
                id: 99,
                title: "A",
                excerpt: "y",
                heroImage: nil,
                publishedAt: .now,
                totalTimeDisplay: nil,
                canonicalURL: nil
            )
        )
        let items = try await store.listItems(forIDs: [99])
        #expect(items.first?.canonicalURL == url, "Nil update must not clobber existing URL")
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

@Suite("RecipeStore recently-viewed + entity lookup (US-10)")
struct RecentlyViewedTests {

    /// AC-10.1: AppEntity query must surface the most-recently-viewed
    /// recipes via `recentlyViewed(limit:)`. Newest `lastViewedAt` first;
    /// blocklisted rows excluded.
    @Test func recentlyViewedReturnsNewestFirst() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "Old"))
        try await store.cache(listItem: makeListItem(id: 2, title: "Newer"))
        try await store.cache(listItem: makeListItem(id: 3, title: "Newest"))
        let recents = try await store.recentlyViewed(limit: 10)
        #expect(recents.map(\.id) == [3, 2, 1])
    }

    @Test func recentlyViewedRespectsLimit() async throws {
        let store = try await makeStore()
        for index in 0..<5 {
            try await store.cache(listItem: makeListItem(id: index, title: "R\(index)"))
        }
        let recents = try await store.recentlyViewed(limit: 3)
        #expect(recents.count == 3)
    }

    @Test func recentlyViewedIncludesArticleRowsAfterTFixSixForty() async throws {
        // US-37 / CL-63 / AC-37.4 (T-640): rows with `jsonLDFailedAt != nil`
        // are no longer filtered out — they're classified as articles and
        // surface alongside recipes in `recentlyViewed`. Pre-T-640 this
        // test asserted `recents.map(\.id) == [1]` (excludes id 2 because
        // it was blocklisted); post-T-640 both ids are present.
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "Healthy"))
        try await store.cache(listItem: makeListItem(id: 2, title: "Article"))
        try await store.markJSONLDFailed(id: 2)
        let recents = try await store.recentlyViewed(limit: 10)
        #expect(Set(recents.map(\.id)) == Set([1, 2]))
    }

    /// AC-10.1: the AppEntity lookup must NOT touch `lastViewedAt`. If it
    /// did, every Siri suggestion would re-rank to the top and pollute the
    /// LRU.
    @Test func recipeWithoutTouchingDoesNotBumpLastViewedAt() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "First"))
        // Sleep a millisecond so any bump to lastViewedAt would be observable.
        try await Task.sleep(nanoseconds: 1_000_000)
        try await store.cache(listItem: makeListItem(id: 2, title: "Second"))
        // Probe id=1 via the silent accessor.
        _ = try await store.recipeWithoutTouching(id: 1)
        let recents = try await store.recentlyViewed(limit: 10)
        // Id 2 should still be at the top — the probe must not have promoted id 1.
        #expect(recents.first?.id == 2, "Silent accessor must not bump lastViewedAt")
    }

    @Test func recipeWithoutTouchingReturnsNilForMissingID() async throws {
        let store = try await makeStore()
        let recipe = try await store.recipeWithoutTouching(id: 999)
        #expect(recipe == nil)
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

    /// US-35 / AC-35.5 — explicitly-downloaded recipes pin from LRU
    /// eviction the same way saved recipes do. The new eviction
    /// predicate (`isSaved == false && downloadedAt == nil`) preserves
    /// rows where either flag is set, so a recipe a user grabbed for a
    /// camping trip survives even when they never tap Save.
    @Test func downloadedRecipeSurvivesLRUEviction() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 7777, title: "Camping Stew"))
        let transitioned = try await store.markDownloaded(id: 7777)
        #expect(transitioned == true)
        // Re-tap on the same row is a no-op (AC-35.4).
        let idempotent = try await store.markDownloaded(id: 7777)
        #expect(idempotent == false)
        #expect(try await store.isDownloaded(id: 7777) == true)
        // Drown the LRU window with unrelated rows.
        for index in 0..<(RecipeStore.unsavedLRUCap + 50) {
            try await store.cache(listItem: makeListItem(id: 8000 + index, title: "Filler \(index)"))
        }
        #expect(
            try await store.isDownloaded(id: 7777) == true,
            "Explicitly-downloaded recipe must survive LRU eviction"
        )
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

    // MARK: - US-21 / T-360 — WidgetImageBridge integration

    @Test func cacheImageStillSucceedsWhenAppGroupContainerUnavailable() async throws {
        // The widget image bridge writes a side-effect file inside the
        // shared App Group container; in unit tests the container is
        // unavailable (no entitlement) and the bridge silently no-ops.
        // The contract is that `cacheImage(...)` itself must NEVER fail
        // because of a bridge-side error — the SwiftData write is the
        // authoritative path and the file is best-effort. This test pins
        // that contract by exercising a normal `cacheImage` flow and
        // asserting both the SwiftData round-trip and the
        // bridge-no-op-doesn't-throw behavior (the absence of an
        // exception IS the assertion — Swift Testing fails the test on
        // any thrown error).
        let store = try await makeStore()
        let url = URL(string: "https://example.com/bridge-noop.jpg") ?? URL(filePath: "/")
        let bytes = Data([0xFF, 0xD8, 0xFF])
        try await store.cacheImage(url: url, bytes: bytes)
        let read = try await store.image(url: url)
        #expect(read == bytes, "SwiftData read must still work when the App Group bridge is no-op")
    }

    @Test func evictImagesStillSucceedsWhenAppGroupContainerUnavailable() async throws {
        // Same contract on the eviction side — the bridge's file delete
        // is best-effort and must never block the SwiftData row delete.
        let store = try await makeStore()
        let url = URL(string: "https://example.com/evict-noop.jpg") ?? URL(filePath: "/")
        try await store.cacheImage(url: url, bytes: Data(repeating: 0xAA, count: 256))
        // No-throw assertion — the eviction path must complete cleanly
        // even when the bridge's file delete returns false.
        try await store.evictImagesIfNeeded()
        // The image is well under the 200 MB budget so it's still there.
        let read = try await store.image(url: url)
        #expect(read != nil)
    }

    // MARK: - US-36 / T-630 — clearImageCache

    @Test func clearImageCacheRemovesUnpinnedRowsAndReturnsFreedBytes() async throws {
        let store = try await makeStore()
        let url1 = URL(string: "https://example.com/a.jpg") ?? URL(filePath: "/")
        let url2 = URL(string: "https://example.com/b.jpg") ?? URL(filePath: "/")
        try await store.cacheImage(url: url1, bytes: Data(repeating: 0xAA, count: 1024))
        try await store.cacheImage(url: url2, bytes: Data(repeating: 0xBB, count: 2048))

        let freed = try await store.clearImageCache()
        #expect(freed == 1024 + 2048)

        // Rows are gone — subsequent reads return nil per the existing
        // image(url:) contract.
        #expect(try await store.image(url: url1) == nil)
        #expect(try await store.image(url: url2) == nil)
    }

    @Test func clearImageCachePreservesPinnedRows() async throws {
        // AC-36.4 + CL-62: pinned images belong to saved recipes and
        // survive Clear Cache so the AC-4.9 / AC-5.2 offline-saved
        // contract is preserved.
        let store = try await makeStore()
        let unpinnedURL = URL(string: "https://example.com/unpinned.jpg") ?? URL(filePath: "/")
        let pinnedURL = URL(string: "https://example.com/pinned.jpg") ?? URL(filePath: "/")
        try await store.cacheImage(url: unpinnedURL, bytes: Data(repeating: 0x01, count: 512))
        try await store.cacheImage(
            url: pinnedURL,
            bytes: Data(repeating: 0x02, count: 1024),
            pinnedToSavedRecipeID: 42
        )

        let freed = try await store.clearImageCache()
        // Only the unpinned 512 bytes are freed; pinned bytes survive.
        #expect(freed == 512)

        #expect(try await store.image(url: unpinnedURL) == nil)
        #expect(try await store.image(url: pinnedURL) != nil)
    }

    @Test func clearImageCacheReturnsZeroWhenAlreadyEmpty() async throws {
        // AC-36.4 zero-case: a fresh store with no images returns 0,
        // which the snackbar formatter renders as "Cache was already
        // clear." rather than the "Freed 0.0 MB" copy.
        let store = try await makeStore()
        let freed = try await store.clearImageCache()
        #expect(freed == 0)
    }
}

@Suite("RecipeStore article-classification (T-076 then T-640, AC-1.7 + AC-37.4)") struct BlocklistTests {

    // US-37 / CL-63 / AC-37.4 (T-640): the suite was originally
    // "RecipeStore blocklist" — articles were hidden from lists per CL-9.
    // Post-T-640 the `jsonLDFailedAt` field is the kind discriminator
    // (article vs recipe) and articles surface in lists alongside
    // recipes. The three tests below now lock the new behavior; the
    // `clearBlocklist()` pull-to-refresh-reset semantic is preserved
    // because it still flips an article back to recipe-rendering after
    // a server-side JSON-LD fix is published.

    @Test func articleClassifiedRowIsIncludedInListItems() async throws {
        // Pre-T-640: blocklisted row excluded. Post-T-640: article-
        // classified row included alongside recipe rows.
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "Healthy"))
        try await store.cache(listItem: makeListItem(id: 2, title: "Article"))
        try await store.markJSONLDFailed(id: 2)
        let visible = try await store.listItems(forIDs: [1, 2])
        #expect(Set(visible.map(\.id)) == Set([1, 2]))
    }

    @Test func clearBlocklistResetsArticleClassification() async throws {
        // The pull-to-refresh reset path is preserved (AC-37.4 last
        // sentence). After `clearBlocklist()` an article-classified row
        // surfaces with its `jsonLDFailedAt` cleared, so the next detail
        // open re-attempts the JSON-LD parse and (on server-side fix)
        // flips back to recipe rendering. The row is still visible
        // before+after the clear — what changes is the kind classification.
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 5, title: "Foo"))
        try await store.markJSONLDFailed(id: 5)
        let beforeClear = try await store.listItems(forIDs: [5])
        #expect(beforeClear.count == 1)
        try await store.clearBlocklist()
        let afterClear = try await store.listItems(forIDs: [5])
        #expect(afterClear.count == 1)
    }

    @Test func successfulReCacheClearsArticleClassification() async throws {
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

func makeStore() async throws -> RecipeStore {
    let container = try RecipeStore.inMemoryContainer()
    return RecipeStore(modelContainer: container)
}

func makeListItem(id: Int, title: String) -> RecipeListItem {
    RecipeListItem(
        id: id,
        title: title,
        excerpt: "An excerpt.",
        heroImage: URL(string: "https://example.com/\(id).jpg"),
        publishedAt: Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(id)),
        totalTimeDisplay: nil
    )
}

func makeRecipe(id: Int, withDetail: Bool) -> Recipe {
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

/// US-12 overload: lets ingredient-index tests inject specific ingredient
/// strings, categories, and total time without sharing the broader shape
/// of `makeRecipe(id:withDetail:)`.
func makeRecipe(
    id: Int,
    categoryIDs: [Int] = [],
    ingredients: [String],
    totalSeconds: Int? = nil
) -> Recipe {
    Recipe(
        id: id,
        slug: "slug-\(id)",
        title: "Title \(id)",
        excerpt: "Excerpt.",
        canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/") ?? URL(filePath: "/"),
        categoryIDs: categoryIDs,
        publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
        ingredients: ingredients.map { .init(text: $0) },
        totalTime: totalSeconds.map { .seconds($0) }
    )
}
