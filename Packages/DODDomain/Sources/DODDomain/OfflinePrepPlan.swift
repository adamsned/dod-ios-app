import Foundation

/// DUT-999 — the set of image URLs a recipe needs cached to cook fully offline.
public struct OfflinePrepPlan: Sendable, Equatable {
    /// Hero large first, then hero small, then equipment images; de-duplicated, order preserved.
    public let imageURLs: [URL]

    public init(recipe: Recipe, equipment: [Equipment] = []) {
        var seen = Set<URL>()
        var ordered: [URL] = []
        let candidates: [URL?] =
            [recipe.heroImageLargeURL, recipe.heroImage] + equipment.map(\.imageURL)
        for case let url? in candidates where seen.insert(url).inserted {
            ordered.append(url)
        }
        self.imageURLs = ordered
    }
}
