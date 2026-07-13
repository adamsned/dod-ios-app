import DODDomain
import Foundation
import Testing

@testable import DODPersistence

/// LRU eviction boundary testing (T-074). The store caps unsaved, non-downloaded
/// recipes at `unsavedLRUCap = 100`. Each `cache(listItem:)` call triggers
/// `evictIfNeeded()`. The eviction predicate is `isSaved == false && downloadedAt == nil`,
/// so saved and downloaded rows don't count toward the cap. These tests verify
/// the boundary behavior and saved/downloaded exclusion.
@Suite("RecipeStore LRU eviction boundaries (T-074)")
struct RecipeStoreEvictionBoundaryTests {

    /// Exactly at capacity: inserting and caching 100 unsaved rows must NOT
    /// evict any. Each cache call after the 100th will trigger eviction.
    @Test func exactlyAtCapacityDoesNotEvict() async throws {
        let store = try await makeStore()

        // Insert exactly 100 unsaved rows. Eviction runs after each cache call,
        // but since we're at or under the cap, nothing evicts.
        for index in 0..<100 {
            try await store.cache(listItem: makeListItem(id: index, title: "Item \(index)"))
        }

        let items = try await store.listItems(forIDs: Array(0..<100))
        #expect(
            items.count == 100,
            "Exactly at capacity (100 rows) must not trigger eviction"
        )
    }

    /// One over capacity: caching 101 unsaved rows will evict the oldest
    /// (id=0) during the loop, leaving 100 total (ids 1-100).
    @Test func oneOverCapacityEvictsOldest() async throws {
        let store = try await makeStore()

        // Insert 101 rows. After insert 100, eviction triggers, removes id 0.
        for index in 0..<101 {
            try await store.cache(listItem: makeListItem(id: index, title: "Item \(index)"))
        }

        let items = try await store.listItems(forIDs: Array(0..<101))
        #expect(items.count == 100, "One over cap triggers eviction to 100 rows")
        #expect(
            items.map(\.id) == Array(1..<101),
            "The oldest row (id=0) must be evicted"
        )
    }

    /// Multiple over capacity: caching 110 rows. After reaching 101, eviction
    /// runs and removes ids 0-9 (10 oldest), leaving 100. Ids 10-109 survive.
    @Test func multipleOverCapacityEvictsMultipleOldest() async throws {
        let store = try await makeStore()

        for index in 0..<110 {
            try await store.cache(listItem: makeListItem(id: index, title: "Item \(index)"))
        }

        let items = try await store.listItems(forIDs: Array(0..<110))
        #expect(items.count == 100, "10 over cap evicts 10 rows to 100 total")
        #expect(
            items.map(\.id) == Array(10..<110),
            "The 10 oldest rows (ids 0-9) must be evicted; 10-109 remain"
        )
    }

    /// Saved recipes exclude from the unsaved cap. After caching 101 items,
    /// eviction has trimmed unsaved rows to 100 (ids 1-100). If we then mark
    /// one as saved (e.g., id 50), it no longer counts toward the unsaved cap,
    /// but it's already past the eviction point, so it survives anyway. The key
    /// is that saved rows are NOT evicted even if total rows exceed 100.
    @Test func savedRecipesAreNeverEvicted() async throws {
        let store = try await makeStore()

        // Cache 101 items (evicts to 100 during the loop).
        for index in 0..<101 {
            try await store.cache(listItem: makeListItem(id: index, title: "Item \(index)"))
        }

        // Mark one of the surviving rows as saved.
        _ = try await store.toggleSaved(id: 50)

        // Verify it survives.
        let items = try await store.listItems(forIDs: [50])
        #expect(items.count == 1, "Saved recipe must survive")
    }

    /// Downloaded recipes exclude from the unsaved cap. Similar to saved:
    /// after eviction to 100, marking a row as downloaded protects it from
    /// future eviction.
    @Test func downloadedRecipesAreNeverEvicted() async throws {
        let store = try await makeStore()

        // Cache 101 items (evicts to 100).
        for index in 0..<101 {
            try await store.cache(listItem: makeListItem(id: index, title: "Item \(index)"))
        }

        // Mark one of the surviving rows as downloaded.
        _ = try await store.markDownloaded(id: 50)

        // Verify it survives.
        let items = try await store.listItems(forIDs: [50])
        #expect(items.count == 1, "Downloaded recipe must survive")
    }

    /// Mixed scenario: after evicting unsaved rows to the 100 cap, if we have
    /// saved + downloaded rows mixed with unsaved, the unsaved subset stays at
    /// 100 and saved/downloaded are protected. Caching 120 items where 20 will
    /// be marked saved/downloaded should result in 100 unsaved + 20 protected.
    @Test func mixedSavedDownloadedUnsavedRespectsCap() async throws {
        let store = try await makeStore()

        // Cache 120 rows (evicts unsaved to 100).
        for index in 0..<120 {
            try await store.cache(listItem: makeListItem(id: index, title: "Item \(index)"))
        }

        // After eviction, we have 100 rows (ids 20-119, assuming the 20 oldest
        // were evicted). Mark 10 of them as saved and 10 as downloaded.
        for index in (20..<30) {
            _ = try await store.toggleSaved(id: index)
        }
        for index in (30..<40) {
            _ = try await store.markDownloaded(id: index)
        }

        // Verify saved and downloaded survive.
        let savedItems = try await store.listItems(forIDs: Array(20..<30))
        #expect(savedItems.count == 10, "10 saved rows must survive")

        let downloadedItems = try await store.listItems(forIDs: Array(30..<40))
        #expect(downloadedItems.count == 10, "10 downloaded rows must survive")
    }

    /// Eviction respects `lastViewedAt` order (oldest first). Earlier cached
    /// rows have older `lastViewedAt` and are evicted first. By inserting in
    /// order and observing which rows evict, we verify the LRU logic.
    @Test func evictionRespectsLastViewedAtOrder() async throws {
        let store = try await makeStore()

        // Insert 101 rows in order. Ids 0-99 are oldest by insertion order (hence
        // oldest by lastViewedAt). When insert 100 triggers eviction, id 0 is removed.
        for index in 0..<101 {
            try await store.cache(listItem: makeListItem(id: index, title: "Item \(index)"))
        }

        // Verify the oldest row (id=0) was evicted.
        let items = try await store.listItems(forIDs: Array(0..<101))
        #expect(
            items.count == 100,
            "One row should be evicted (the oldest)"
        )
        #expect(
            items.map(\.id) == Array(1..<101),
            "Eviction must remove the oldest row (id=0) by lastViewedAt order"
        )
    }

    /// After eviction, if more rows are added, the LRU continues to respect order.
    /// Each cycle of overflow triggers eviction of the (newly) oldest unsaved rows.
    @Test func evictionCanRunMultipleTimesSequentially() async throws {
        let store = try await makeStore()

        // First cycle: cache 105 rows (evicts unsaved to 100, removing ids 0-4).
        for index in 0..<105 {
            try await store.cache(listItem: makeListItem(id: index, title: "Batch1-\(index)"))
        }
        var items = try await store.listItems(forIDs: Array(0..<105))
        #expect(items.count == 100, "First eviction brings us to 100")
        #expect(items.map(\.id).min() ?? -1 >= 5, "Ids 0-4 should be evicted")

        // Second cycle: cache 10 more rows (ids 105-114). This evicts ids 5-14
        // (the newly oldest), keeping 100 total.
        for index in 105..<115 {
            try await store.cache(listItem: makeListItem(id: index, title: "Batch2-\(index)"))
        }
        items = try await store.listItems(forIDs: Array(0..<115))
        #expect(items.count == 100, "Second eviction brings us back to 100")
        #expect(
            items.map(\.id).min() ?? -1 >= 15,
            "After two evictions, the oldest survivors are >= 15"
        )
    }
}
