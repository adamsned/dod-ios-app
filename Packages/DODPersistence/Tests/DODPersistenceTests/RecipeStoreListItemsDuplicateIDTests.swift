import DODDomain
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// `CachedRecipe.id` carries NO `@Attribute(.unique)` — CloudKit mirroring
/// forbids unique constraints on synced models — so two rows CAN legitimately
/// share an id (the same mechanism DUT-650 documents for `SyncedSavedRecipe`,
/// and DUT-702 already fixed for the sibling `categoryIDs(forRecipeIDs:)`).
/// `listItems(forIDs:)` is the list-rendering hot path used by Feed, Search,
/// Categories, and TabStack, and built its lookup with
/// `Dictionary(uniqueKeysWithValues:)`, which traps the moment a duplicate row
/// exists. This locks the duplicate-tolerant fix.
@Suite("RecipeStore.listItems(forIDs:) tolerates duplicate CachedRecipe ids")
struct RecipeStoreListItemsDuplicateIDTests {

    private func dupRow(id: Int, title: String) -> CachedRecipe {
        CachedRecipe(
            id: id,
            slug: "dup-\(id)",
            title: title,
            excerptText: "Excerpt",
            canonicalURLString: "https://dutchovendaddy.com/\(id)",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test("does not trap when two CachedRecipe rows share an id")
    func toleratesDuplicateRowsWithSameID() async throws {
        let container = try RecipeStore.inMemoryContainer()

        // Insert two CachedRecipe rows sharing id 40 directly (bypassing the
        // store's own upsert path), reproducing the CloudKit-mirrored
        // duplicate scenario the schema permits.
        let setup = ModelContext(container)
        setup.insert(dupRow(id: 40, title: "First Row"))
        setup.insert(dupRow(id: 40, title: "Second Row"))
        try setup.save()

        let store = RecipeStore(modelContainer: container)

        // Must not trap (Dictionary(uniqueKeysWithValues:) would fatalError
        // here on the un-fixed code) and must return exactly one item for the
        // duplicated id.
        let items = try await store.listItems(forIDs: [40])
        #expect(items.count == 1, "duplicate rows for one id must collapse to a single list item")
        #expect(items.first?.id == 40)
    }

    @Test("preserves caller ordering and includes non-duplicated ids")
    func preservesOrderingAlongsideDuplicate() async throws {
        let container = try RecipeStore.inMemoryContainer()

        let setup = ModelContext(container)
        setup.insert(dupRow(id: 1, title: "Solo"))
        setup.insert(dupRow(id: 2, title: "Dup A"))
        setup.insert(dupRow(id: 2, title: "Dup B"))
        try setup.save()

        let store = RecipeStore(modelContainer: container)
        let items = try await store.listItems(forIDs: [2, 1])

        #expect(items.map(\.id) == [2, 1], "result order must follow the requested id order")
    }
}
