import DODDomain
import Foundation
import SwiftData

// MARK: - DUT-257 / DUT-556: bulk list-item cache
//
// Extracted from RecipeStore.swift to keep that file under the SwiftLint
// 400-line file_length cap. Houses the batched `cache(listItems:)` path (a
// single post-loop save + eviction, DUT-257) and its intra-batch dedup
// (DUT-556).

extension RecipeStore {

    /// Bulk cache a list response so list screens can hydrate offline (AC-1.6).
    /// DUT-257 — upsert every row, then `save()` + `evictIfNeeded()` EXACTLY
    /// ONCE (the prior `cache(listItem:)` loop ran N saves + N LRU fetch+sorts).
    public func cache(listItems: [RecipeListItem]) throws {
        guard !listItems.isEmpty else { return }
        // DUT-556: de-dup the batch by `id` (keeping the LAST occurrence per id,
        // matching the old per-item-save path where item N overwrote item M<N)
        // BEFORE the loop. There is NO per-item save here (DUT-257) and
        // `CachedRecipe.id` has NO `@Attribute(.unique)` (dropped for CloudKit /
        // DOD-CRASH-1), so two items sharing one id would each `fetchRecipe(id:)`
        // → nil and `insert` a SECOND row if SwiftData's fetch doesn't surface
        // the still-pending in-loop insert. De-duping here guarantees exactly one
        // `CachedRecipe` per id regardless of pending-insert fetch semantics,
        // while preserving the DUT-257 single post-loop save + eviction.
        for item in Self.dedupedByIDKeepingLast(listItems) {
            try upsert(listItem: item)
        }
        try modelContext.save()
        try evictIfNeeded()
    }

    /// DUT-556 — collapse a batch to one item per `id`, keeping the LAST
    /// occurrence (so a later row in the same response wins, matching the old
    /// per-item-save upsert order). Preserves first-seen ordering of the kept
    /// ids so downstream inserts stay stable.
    static func dedupedByIDKeepingLast(
        _ items: [RecipeListItem]
    ) -> [RecipeListItem] {
        var lastByID: [Int: RecipeListItem] = [:]
        var order: [Int] = []
        for item in items {
            if lastByID[item.id] == nil {
                order.append(item.id)
            }
            lastByID[item.id] = item
        }
        return order.compactMap { lastByID[$0] }
    }

    #if DEBUG
    /// DUT-556 test seam: the RAW number of `CachedRecipe` rows for an id (not
    /// deduped by the reader), so a test can prove `cache(listItems:)` never
    /// double-inserts on a duplicate id within one batch. Not for production —
    /// production readers already dedup via `fetchRecipe(id:)`.
    func cachedRowCount(id: Int) throws -> Int {
        try modelContext.fetch(
            FetchDescriptor<CachedRecipe>(predicate: #Predicate { $0.id == id })
        ).count
    }
    #endif
}
