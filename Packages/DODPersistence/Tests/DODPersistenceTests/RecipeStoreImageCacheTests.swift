import DODDomain
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// Image-cache pin / Clear Cache coverage (T-075), split out of `RecipeStoreTests`
/// so that file stays under the SwiftLint `file_length` cap. Uses the shared
/// top-level `makeStore()` / `makeListItem(...)` helpers.
@Suite("RecipeStore image cache pinning (T-075 / DUT-380)")
struct RecipeStoreImageCachePinTests {

    @Test func clearImageCachePreservesPinnedRows() async throws {
        // AC-36.4 + CL-62: pinned images belong to saved recipes and survive Clear
        // Cache so the AC-4.9 / AC-5.2 offline-saved contract is preserved.
        let store = try await makeStore()
        // DUT-380: a pin is now honored only while its recipe is genuinely saved /
        // downloaded (an explicit pin that raced an unsave used to leak). Seed
        // recipe 42 as saved so its pinned hero is legitimately preserved.
        try await store.cache(listItem: makeListItem(id: 42, title: "Pinned"))
        _ = try await store.markSaved(id: 42)
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

    @Test func explicitPinToUnsavedRecipeIsNotHonored() async throws {
        // DUT-380: a download whose recipe was unsaved mid-flight must NOT pin its
        // bytes to that recipe — an orphan pin escapes both eviction and Clear
        // Cache forever. Recipe 99 is neither saved nor downloaded here.
        let store = try await makeStore()
        let url = URL(string: "https://example.com/orphan.jpg") ?? URL(filePath: "/")
        try await store.cacheImage(
            url: url,
            bytes: Data(repeating: 0x03, count: 256),
            pinnedToSavedRecipeID: 99
        )
        // The pin was dropped (recipe not live), so Clear Cache reclaims it.
        let freed = try await store.clearImageCache()
        #expect(freed == 256)
        #expect(try await store.image(url: url) == nil)
    }
}
