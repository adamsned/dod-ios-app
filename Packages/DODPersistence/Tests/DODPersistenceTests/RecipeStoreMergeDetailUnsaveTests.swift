import DODDomain
import Foundation
import Testing

@testable import DODPersistence

/// DUT-512: `mergeDetail`'s downward reconcile (a cross-device unsave observed on
/// detail-open, once the DUT-302 backfill is complete) used to clear only
/// `isSaved` — UNLIKE the explicit `toggleSaved` unsave (DUT-215) it left
/// `downloadedAt` set (so the orphaned `CachedRecipe` was never evicted — its
/// predicate needs `downloadedAt == nil`) and never cleared the write-once
/// `pinnedToSavedRecipeID` (so the pinned hero bytes leaked against the image
/// budget forever, un-reclaimable by eviction OR Settings ▸ clear cache).
/// `mergeDetail` now mirrors the explicit-unsave teardown.
@Suite("RecipeStore mergeDetail cross-device unsave teardown (DUT-512)")
struct RecipeStoreMergeDetailUnsaveTests {

    @Test func crossDeviceUnsaveTearsDownDownloadAndUnpinsHero() async throws {
        let store = try await makeStore()
        // `makeListItem` sets hero to https://example.com/{id}.jpg; `mergeDetail`
        // does not clobber `heroImageURLString`, so the pin survives the merge.
        let heroURL = URL(string: "https://example.com/512.jpg") ?? URL(filePath: "/")
        try await store.cache(listItem: makeListItem(id: 512, title: "Peach Cobbler"))

        // Local state: saved + downloaded + a pinned hero (as if saved on THIS
        // device pre-migration, then unsaved on ANOTHER device).
        try await store.seedLegacyLocalSaveForTesting(id: 512)
        _ = try await store.markDownloaded(id: 512)
        try await store.cacheImage(
            url: heroURL,
            bytes: Data(repeating: 0x02, count: 1024),
            pinnedToSavedRecipeID: 512
        )
        #expect(try await store.localIsSavedPinForTesting(id: 512))
        #expect(try await store.isDownloaded(id: 512) == true)

        // Post-migration the synced set is authoritative. With NO synced row
        // (the cross-device unsave), opening the recipe reconciles downward.
        await store.markSyncedSavedBackfillComplete()
        try await store.mergeDetail(makeRecipe(id: 512, withDetail: true))

        // isSaved cleared…
        #expect(!(try await store.localIsSavedPinForTesting(id: 512)))
        // …downloadedAt cleared (so eviction can reclaim the CachedRecipe)…
        #expect(try await store.isDownloaded(id: 512) == false)
        // …and the hero unpinned → clear-cache reclaims the bytes (pre-fix the
        // write-once pin survived forever).
        let freed = try await store.clearImageCache()
        #expect(freed == 1024)
        #expect(try await store.image(url: heroURL) == nil)
    }

    /// DUT-512 follow-up: the cross-device-unsave teardown above must NOT fire
    /// for a recipe that was explicitly DOWNLOADED but never saved (US-35 /
    /// DUT-67 — download and save are independent states). Before this fix,
    /// the reconcile branch keyed only on "no synced row + backfill complete",
    /// which is also true for every download-only recipe (it never had a
    /// synced row to begin with) — so an ordinary re-open or pull-to-refresh
    /// (any `mergeDetail` call, not just a migration-window race) silently
    /// cleared `downloadedAt` and unpinned the hero, destroying the offline
    /// download the user never asked to remove.
    @Test func downloadOnlyRecipeSurvivesMergeDetailReconcile() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 9001, title: "Dutch Baby"))

        // Explicitly download without ever saving.
        _ = try await store.markDownloaded(id: 9001)
        #expect(try await store.isDownloaded(id: 9001))
        #expect(!(try await store.localIsSavedPinForTesting(id: 9001)))

        // Steady-state backfill-complete — the normal state for essentially
        // every real user, not just mid-migration.
        await store.markSyncedSavedBackfillComplete()

        // Re-open the recipe (or pull-to-refresh): mergeDetail runs again, as it
        // does on every detail fetch (`RecipeDetailViewModel+Fetch.apply`).
        try await store.mergeDetail(makeRecipe(id: 9001, withDetail: true))

        // The explicit download must survive — this was never a saved row, so
        // it's not a cross-device unsave.
        #expect(try await store.isDownloaded(id: 9001))
    }

    @Test func upwardReconcileStillPinsHeroNoRegression() async throws {
        // Regression guard: the same-user / upward path (a synced saved row
        // present) must still pin the hero on merge, keeping it eviction-proof.
        let store = try await makeStore()
        let heroURL = URL(string: "https://example.com/777.jpg") ?? URL(filePath: "/")
        try await store.cache(listItem: makeListItem(id: 777, title: "Chili"))
        // Save it → writes the synced source of truth.
        _ = try await store.markSaved(id: 777)
        // Cache the hero WITHOUT a pin (the post-save widget prefetch path).
        try await store.cacheImage(
            url: heroURL,
            bytes: Data(repeating: 0x03, count: 1024)
        )

        await store.markSyncedSavedBackfillComplete()
        try await store.mergeDetail(makeRecipe(id: 777, withDetail: true))

        // Synced row present → mergeDetail pins the hero; clear-cache can't
        // reclaim it and the bytes remain.
        #expect(try await store.localIsSavedPinForTesting(id: 777))
        let freed = try await store.clearImageCache()
        #expect(freed == 0)
        #expect(try await store.image(url: heroURL) != nil)
    }
}
