import DODDomain
import Foundation
import Testing

@testable import DODPersistence

/// DUT-131: `savedRecipeIDsPendingDownload()` = saved ids minus downloaded ids.
@Suite("RecipeStore offline sync (DUT-131)") struct RecipeStoreOfflineSyncTests {

    /// 3 saved recipes, one of them downloaded -> only the other two are pending.
    @Test func pendingExcludesDownloadedSavedRecipes() async throws {
        let store = try await makeStore()
        for id in 1...3 {
            try await store.cache(listItem: makeListItem(id: id, title: "Recipe \(id)"))
        }
        for id in 1...3 {
            try await store.markSaved(id: id)
        }
        try await store.markDownloaded(id: 2)

        let pending = try await store.savedRecipeIDsPendingDownload()
        #expect(pending == [1, 3])
    }

    /// All saved recipes are pending download.
    @Test func allSavedRecipesArePending() async throws {
        let store = try await makeStore()
        for id in 1...3 {
            try await store.cache(listItem: makeListItem(id: id, title: "Recipe \(id)"))
            try await store.markSaved(id: id)
        }

        let pending = try await store.savedRecipeIDsPendingDownload()
        #expect(pending == [1, 2, 3])
    }

    /// No saved recipes -> no pending downloads.
    @Test func noSavedRecipes() async throws {
        let store = try await makeStore()

        let pending = try await store.savedRecipeIDsPendingDownload()
        #expect(pending.isEmpty)
    }
}
