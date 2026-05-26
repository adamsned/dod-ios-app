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
    /// Optional so older Codable payloads (pre-this-field) decode cleanly.
    /// New REST responses populate it from `post.link` — required for
    /// recipe-detail navigation (spec.md AC-4.* + CL-4).
    public let canonicalURL: URL?
    /// WP category IDs the recipe is tagged with, sourced from the REST
    /// `posts` payload (every search / feed / category hit carries them on
    /// the wire). Optional so older Codable payloads (pre-CL-53) decode
    /// cleanly. `nil` means "categories were not supplied on the wire"
    /// (e.g. a `RecipeListItem` constructed from a non-REST source such
    /// as the local cache before T-530 landed); an empty array means
    /// "REST confirmed zero categories." See CL-53 / REG-17 / T-530 —
    /// this field is what lets the Search-tab category chip filter
    /// freshly-fetched REST results without waiting for a recipe-detail
    /// open to hydrate `CachedRecipe.categoryIDs` via the JSON-LD merge
    /// path.
    public let categoryIDs: [Int]?

    public init(
        id: Int,
        title: String,
        excerpt: String,
        heroImage: URL? = nil,
        publishedAt: Date,
        totalTimeDisplay: String? = nil,
        canonicalURL: URL? = nil,
        categoryIDs: [Int]? = nil
    ) {
        self.id = id
        self.title = title
        self.excerpt = excerpt
        self.heroImage = heroImage
        self.publishedAt = publishedAt
        self.totalTimeDisplay = totalTimeDisplay
        self.canonicalURL = canonicalURL
        self.categoryIDs = categoryIDs
    }
}
