import DODDomain
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// DUT-257 — `cache(listItems:)` must save + run the full-table LRU eviction
/// ONCE for the whole batch, not once per item. The prior implementation looped
/// `cache(listItem:)`, so a 20-item feed page ran 20 saves and 20 full-table
/// LRU fetch+sorts on the store actor — quadratic-ish main-actor churn on every
/// page load. These assert the batch behavior via the `evictIfNeededCallCount`
/// spy, plus that the batch still upserts every row correctly.
@Suite("RecipeStore batch cache (DUT-257)")
struct RecipeStoreBatchCacheTests {

    @Test func bulkCacheRunsEvictionExactlyOncePerBatch() async throws {
        let store = try await makeStore()
        let page = (0..<20).map { makeListItem(id: $0, title: "Item \($0)") }

        try await store.cache(listItems: page)

        // One eviction pass for the whole 20-item page (was 20 before DUT-257).
        #expect(await store.evictIfNeededCallCount == 1)
    }

    @Test func bulkCacheStillPersistsEveryRow() async throws {
        let store = try await makeStore()
        let page = (100..<110).map { makeListItem(id: $0, title: "Row \($0)") }

        try await store.cache(listItems: page)

        let ids = Array(100..<110)
        let items = try await store.listItems(forIDs: ids)
        #expect(items.count == 10)
        #expect(Set(items.map(\.id)) == Set(ids))
    }

    @Test func emptyBatchDoesNoWork() async throws {
        let store = try await makeStore()

        try await store.cache(listItems: [])

        // An empty page short-circuits — no save, no eviction pass.
        #expect(await store.evictIfNeededCallCount == 0)
    }

    /// Guard the contrast: the single-item entry point still saves + evicts
    /// per call (N single calls ⇒ N eviction passes), which is exactly why the
    /// bulk path had to stop delegating to it.
    @Test func singleItemPathStillEvictsPerCall() async throws {
        let store = try await makeStore()

        try await store.cache(listItem: makeListItem(id: 1, title: "A"))
        try await store.cache(listItem: makeListItem(id: 2, title: "B"))
        try await store.cache(listItem: makeListItem(id: 3, title: "C"))

        #expect(await store.evictIfNeededCallCount == 3)
    }

    /// DUT-556 — a batch containing the same `id` twice must yield EXACTLY ONE
    /// `CachedRecipe` row. `CachedRecipe.id` has no `@Attribute(.unique)` (dropped
    /// for CloudKit / DOD-CRASH-1) and the DUT-257 batch path has no per-item
    /// save, so without the pre-loop dedup a second insert could slip through if
    /// SwiftData's fetch doesn't surface the still-pending in-loop insert. The
    /// dedup keeps the LAST occurrence, so the winning row carries its title.
    @Test func duplicateIDWithinOneBatchYieldsExactlyOneRow() async throws {
        let store = try await makeStore()

        try await store.cache(listItems: [
            makeListItem(id: 42, title: "First"),
            makeListItem(id: 42, title: "Last"),
        ])

        // Exactly one row for the duplicated id (was a risk of two before the fix).
        let rowCount = try await store.cachedRowCount(id: 42)
        #expect(rowCount == 1)

        // Last-write-wins: the second occurrence's title is the one persisted.
        let items = try await store.listItems(forIDs: [42])
        #expect(items.count == 1)
        #expect(items.first?.title == "Last")
    }
}
