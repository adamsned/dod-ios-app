import DODDomain
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// DUT-650 — CloudKit can leave two `SyncedSavedRecipe` rows for one id with
/// different `savedAt` (no `@Attribute(.unique)` on a mirrored model). The Saved
/// tab (`savedRecipesWithSavedAt()`) sorts DESCENDING and displays the NEWEST
/// duplicate, but the `upsertSyncedSaved` collapse used to keep the EARLIEST and
/// delete the rest — so a re-save collapsed the dup to the old row and the recipe
/// jumped back to its old Saved-tab position. The collapse must keep the
/// max-`savedAt` (newest) row so the two paths agree.
@Suite("Synced saved duplicate collapse keeps newest (DUT-650)")
struct SyncedSavedDuplicateCollapseTests {

    private func syncedDup(id: Int, savedAt: Date) -> SyncedSavedRecipe {
        SyncedSavedRecipe(
            id: id,
            savedAt: savedAt,
            title: "Dup",
            excerptText: "Excerpt",
            canonicalURLString: "https://dutchovendaddy.com/\(id)"
        )
    }

    @Test("upsertSyncedSaved collapse keeps the NEWEST duplicate row")
    func collapseKeepsNewestDuplicate() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        let new = Date(timeIntervalSince1970: 1_700_009_999)
        let setup = ModelContext(container)
        setup.insert(syncedDup(id: 40, savedAt: old))  // oldest inserted first
        setup.insert(syncedDup(id: 40, savedAt: new))
        setup.insert(
            CachedRecipe(
                id: 40,
                slug: "collapse",
                title: "Re-saved Title",
                excerptText: "Excerpt",
                canonicalURLString: "https://dutchovendaddy.com/40",
                publishedAt: old
            )
        )
        try setup.save()

        let store = RecipeStore(modelContainer: container)
        try await store.performUpsertSyncedSavedForTesting(id: 40)

        let verify = ModelContext(container)
        let survivors = try verify.fetch(
            FetchDescriptor<SyncedSavedRecipe>(predicate: #Predicate { $0.id == 40 })
        )
        #expect(survivors.count == 1, "the duplicate rows must collapse to one")
        #expect(survivors.first?.savedAt == new, "the surviving row must be the NEWEST")
    }
}
