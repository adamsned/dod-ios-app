import DODDomain
import DODNetworking
import DODPersistence
import Foundation

public protocol SavedDependencies: Sendable {
    func savedRecipes() async throws -> [Recipe]
    /// Pre-download hero images for newly-saved recipe (AC-5.2).
    func preDownloadImages(forRecipeID: Int, urls: [URL]) async
}

public struct LiveSavedDependencies: SavedDependencies {
    let store: RecipeStore
    let imageLoader: ImageLoader

    public init(store: RecipeStore, imageLoader: ImageLoader) {
        self.store = store
        self.imageLoader = imageLoader
    }

    public func savedRecipes() async throws -> [Recipe] {
        try await store.savedRecipes()
    }

    public func preDownloadImages(forRecipeID recipeID: Int, urls: [URL]) async {
        for url in urls {
            guard let bytes = try? await imageLoader.data(for: url) else { continue }
            try? await store.cacheImage(url: url, bytes: bytes, pinnedToSavedRecipeID: recipeID)
        }
    }
}
