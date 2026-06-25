import DODDomain
import Foundation
import Testing

@testable import DODPersistence

/// DUT-302: on the V5 upgrade an upgrader's saves exist only as local
/// `CachedRecipe.isSaved` pins; the synced store (`SyncedSavedRecipe`) starts
/// empty and is seeded once by `backfillSyncedSaved()`. `mergeDetail` runs on
/// every detail open and used to blindly set `isSaved = (synced != nil)` — so
/// opening a previously-saved recipe BEFORE the backfill flipped the pin
/// true→false, the backfill (which selects `isSaved == true`) then missed it,
/// and the save was permanently lost. `mergeDetail` now preserves a legacy pin
/// until the backfill is marked complete.
///
/// (`isSaved(id:)` reads the synced source of truth, so the pin itself is
/// observed via the `localIsSavedPinForTesting` DEBUG seam.)
@Suite("RecipeStore upgrade-race (DUT-302)") struct RecipeStoreUpgradeRaceTests {

    @Test func mergeDetailPreservesTheLegacyPinBeforeTheBackfill() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 808, title: "Cobbler"))
        // Pre-V5 upgrade state: a local isSaved pin with NO synced row.
        try await store.seedLegacyLocalSaveForTesting(id: 808)
        #expect(try await store.localIsSavedPinForTesting(id: 808))

        // Opening the recipe BEFORE the backfill must NOT clear the pin
        // (didBackfillSyncedSaved is still false on a fresh store).
        try await store.mergeDetail(makeRecipe(id: 808, withDetail: true))

        #expect(try await store.localIsSavedPinForTesting(id: 808))  // preserved (pre-fix: cleared)
    }

    @Test func theUpgraderSaveSurvivesTheBackfillAfterAnEarlyMergeDetail() async throws {
        // End-to-end: the data-loss path. Pre-fix, mergeDetail cleared the pin, so
        // the backfill (selecting isSaved == true) missed it → the save vanished
        // from the Saved tab (which reads the synced set) forever.
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 808, title: "Cobbler"))
        try await store.seedLegacyLocalSaveForTesting(id: 808)

        try await store.mergeDetail(makeRecipe(id: 808, withDetail: true))  // before backfill
        try await store.backfillSyncedSaved()  // migrates the still-true pin

        #expect(try await store.isSaved(id: 808))  // synced row created → save survived
    }

    @Test func mergeDetailClearsTheLocalPinOnceTheBackfillIsComplete() async throws {
        // Post-migration the synced set is authoritative: a recipe with no synced
        // row (e.g. unsaved on another device) has its local pin cleared on merge.
        // DUT-302 only DEFERS this reconcile until the backfill is done.
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 9, title: "Chili"))
        try await store.seedLegacyLocalSaveForTesting(id: 9)
        await store.markSyncedSavedBackfillComplete()

        try await store.mergeDetail(makeRecipe(id: 9, withDetail: true))

        #expect(!(try await store.localIsSavedPinForTesting(id: 9)))  // cleared (authoritative)
    }
}
