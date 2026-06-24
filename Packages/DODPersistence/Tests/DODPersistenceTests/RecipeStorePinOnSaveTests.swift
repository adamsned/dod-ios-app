import DODDomain
import Foundation
import Testing

@testable import DODPersistence

/// DUT-292: merely *saving* a recipe (the bookmark / card long-press, not the
/// explicit Download) must pin its hero image so the offline-usable-if-saved
/// contract (AC-5.2) holds — `evictImagesIfNeeded()` + Settings ▸ "free up
/// space" only spare `pinnedToSavedRecipeID != nil` rows. Before the fix no
/// ordinary save path pinned, so a saved-only recipe's hero was evicted the
/// moment the budget was hit and its card / detail hero couldn't render offline.
///
/// `clearImageCache()` frees only *unpinned* rows and returns their byte total,
/// so `freed == 0` (with the bytes still present) proves the hero is pinned.
@Suite("RecipeStore pin-on-save (DUT-292)") struct RecipeStorePinOnSaveTests {

    /// The common case: the hero was already cached (it was on screen) when the
    /// user saved — `toggleSaved` pins the already-cached row.
    @Test func savingPinsAnAlreadyCachedHero() async throws {
        let store = try await makeStore()
        let heroURL = URL(string: "https://example.com/7.jpg") ?? URL(filePath: "/")
        try await store.cache(listItem: makeListItem(id: 7, title: "Cobbler"))
        // Hero cached BEFORE the save with NO explicit pin (the feed/widget
        // prefetch path that previously left saved heroes evictable).
        try await store.cacheImage(url: heroURL, bytes: Data(repeating: 0x03, count: 2048))

        _ = try await store.toggleSaved(id: 7)

        let freed = try await store.clearImageCache()
        #expect(freed == 0)  // pinned → not reclaimed
        #expect(try await store.image(url: heroURL) != nil)  // survives for offline use
    }

    /// The save-from-card race: the recipe is saved before its hero is cached,
    /// then the post-save widget prefetch caches the hero with NO explicit pin —
    /// `cacheImage` must auto-pin it because the recipe is already saved.
    @Test func cachingAHeroForAnAlreadySavedRecipeAutoPins() async throws {
        let store = try await makeStore()
        let heroURL = URL(string: "https://example.com/9.jpg") ?? URL(filePath: "/")
        try await store.cache(listItem: makeListItem(id: 9, title: "Chili"))
        _ = try await store.toggleSaved(id: 9)  // saved first; hero not cached yet

        // Post-save prefetch caches the hero with no pin.
        try await store.cacheImage(url: heroURL, bytes: Data(repeating: 0x04, count: 2048))

        let freed = try await store.clearImageCache()
        #expect(freed == 0)  // auto-pinned → not reclaimed
        #expect(try await store.image(url: heroURL) != nil)
    }

    /// A hero cached for an UNsaved recipe stays unpinned (no over-pinning) — it's
    /// reclaimable, the pre-fix behavior for browsing images.
    @Test func cachingAHeroForAnUnsavedRecipeStaysReclaimable() async throws {
        let store = try await makeStore()
        let heroURL = URL(string: "https://example.com/11.jpg") ?? URL(filePath: "/")
        try await store.cache(listItem: makeListItem(id: 11, title: "Skillet"))

        try await store.cacheImage(url: heroURL, bytes: Data(repeating: 0x05, count: 1024))

        let freed = try await store.clearImageCache()
        #expect(freed == 1024)  // unpinned → reclaimed
        #expect(try await store.image(url: heroURL) == nil)
    }
}
