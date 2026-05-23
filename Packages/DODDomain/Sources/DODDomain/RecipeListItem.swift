import Foundation

/// Lightweight projection of a recipe shown in feeds, category lists, search
/// results, and saved lists. Comes purely from the WP REST API; no JSON-LD
/// parse needed.
///
/// Spec trace: spec.md AC-1.3 (feed row format).
public struct RecipeListItem: Sendable, Hashable, Identifiable, Codable {
    public let id: Int
    public let title: String
    public let excerpt: String
    public let heroImage: URL?
    public let publishedAt: Date
    /// "30 min" if known from REST; nil pre-detail-fetch.
    public let totalTimeDisplay: String?

    public init(
        id: Int,
        title: String,
        excerpt: String,
        heroImage: URL? = nil,
        publishedAt: Date,
        totalTimeDisplay: String? = nil
    ) {
        self.id = id
        self.title = title
        self.excerpt = excerpt
        self.heroImage = heroImage
        self.publishedAt = publishedAt
        self.totalTimeDisplay = totalTimeDisplay
    }
}
