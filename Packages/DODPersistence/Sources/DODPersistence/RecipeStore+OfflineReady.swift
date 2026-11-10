import Foundation
import SwiftData

/// DUT-1668 — how much of a recipe is available without the network.
public struct RecipeOfflineStatus: Sendable, Equatable {
    public let hasDownloadedCard: Bool
    public let hasHeroImage: Bool

    public init(hasDownloadedCard: Bool, hasHeroImage: Bool) {
        self.hasDownloadedCard = hasDownloadedCard
        self.hasHeroImage = hasHeroImage
    }

    public var isFullyCached: Bool { hasDownloadedCard && hasHeroImage }
}

extension RecipeStore {

    /// Non-touching cache-completeness probe (does not bump the image LRU).
    public func offlineStatus(forRecipeID id: Int) throws -> RecipeOfflineStatus {
        guard let row = try fetchRecipe(id: id) else {
            return RecipeOfflineStatus(hasDownloadedCard: false, hasHeroImage: false)
        }
        var hasHero = false
        if let urlString = row.heroImageURLString, let url = URL(string: urlString) {
            hasHero = try imageBytesWithoutTouching(url: url) != nil
        }
        return RecipeOfflineStatus(
            hasDownloadedCard: row.downloadedAt != nil,
            hasHeroImage: hasHero
        )
    }

    /// Batch form for list rows: the subset of `ids` that are fully cached.
    public func fullyCachedIDs(among ids: [Int]) throws -> Set<Int> {
        var result = Set<Int>()
        for id in ids where try offlineStatus(forRecipeID: id).isFullyCached {
            result.insert(id)
        }
        return result
    }
}
