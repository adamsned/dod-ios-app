import DODDomain
import Foundation
import Testing

@testable import DODPersistence

@Suite("RecipeStore offline-ready status (DUT-1668)")
struct RecipeStoreOfflineReadyTests {

    private func heroURL(_ id: Int) -> URL {
        URL(string: "https://example.com/\(id).jpg") ?? URL(filePath: "/")
    }

    @Test func unknownIDIsNotFullyCached() async throws {
        let store = try await makeStore()
        let status = try await store.offlineStatus(forRecipeID: 404)
        #expect(status.isFullyCached == false)
        #expect(status.hasDownloadedCard == false)
        #expect(status.hasHeroImage == false)
    }

    @Test func cachedButNotDownloadedHasNoDownloadedCard() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 1, title: "Listed"))
        let status = try await store.offlineStatus(forRecipeID: 1)
        #expect(status.hasDownloadedCard == false)
        #expect(status.isFullyCached == false)
    }

    @Test func downloadedWithHeroBytesIsFullyCached() async throws {
        let store = try await makeStore()
        try await store.cache(listItem: makeListItem(id: 2, title: "Full"))
        _ = try await store.markDownloaded(id: 2)
        // Downloaded but hero not cached yet: not fully cached.
        #expect(try await store.offlineStatus(forRecipeID: 2).isFullyCached == false)
        try await store.cacheImage(
            url: heroURL(2),
            bytes: Data(repeating: 0x01, count: 128),
            pinnedToSavedRecipeID: 2
        )
        let status = try await store.offlineStatus(forRecipeID: 2)
        #expect(status.hasDownloadedCard)
        #expect(status.hasHeroImage)
        #expect(status.isFullyCached)
        let ids = try await store.fullyCachedIDs(among: [2, 999])
        #expect(ids == [2])
    }
}
