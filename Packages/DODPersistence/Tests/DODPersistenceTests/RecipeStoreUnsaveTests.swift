import DODDomain
import Foundation
import Testing

@testable import DODPersistence

/// DUT-215: unsaving a *downloaded* recipe must tear down both the offline
/// download flag AND the hero-image pin. Before the fix `toggleSaved`'s unsave
/// branch left `downloadedAt` set (so the orphaned `CachedRecipe` was never
/// evicted — its predicate needs `downloadedAt == nil`) and never cleared the
/// write-once `pinnedToSavedRecipeID` (so the pinned bytes leaked against the
/// image budget forever, un-reclaimable by eviction OR Settings ▸ clear cache).
@Suite("RecipeStore unsave teardown (DUT-215)") struct RecipeStoreUnsaveTests {

    @Test func unsavingTearsDownDownloadAndUnpinsImages() async throws {
        let store = try await makeStore()
        let heroURL = URL(string: "https://example.com/hero-42.jpg") ?? URL(filePath: "/")
        try await store.cache(listItem: makeListItem(id: 42, title: "Lasagna"))
        _ = try await store.markSaved(id: 42)
        _ = try await store.markDownloaded(id: 42)
        try await store.cacheImage(
            url: heroURL,
            bytes: Data(repeating: 0x02, count: 1024),
            pinnedToSavedRecipeID: 42
        )
        #expect(try await store.isDownloaded(id: 42) == true)

        // Unsave.
        let unsaved = try await store.toggleSaved(id: 42)
        #expect(unsaved == false)

        // The download flag is cleared (so eviction can reclaim the CachedRecipe).
        #expect(try await store.isDownloaded(id: 42) == false)
        // The hero image is unpinned → clear-cache can now reclaim it (before
        // the fix the pin was write-once, so the bytes survived forever).
        let freed = try await store.clearImageCache()
        #expect(freed == 1024)
        #expect(try await store.image(url: heroURL) == nil)
    }
}
