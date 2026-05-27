import Foundation
import SwiftData

/// Local cache of a recipe. Populated in two phases:
/// 1. List-fetch fields written when a `RecipeListItem` first appears in any list.
/// 2. Detail-fetch fields populated after JSON-LD parse on first detail open.
///
/// Cache policies (NFR-1, plan §2):
/// - LRU window: 100 unsaved rows max, oldest `lastViewedAt` evicted first.
/// - `isSaved == true` rows are pinned and never evicted.
/// - `jsonLDFailedAt != nil` rows are blocklisted from list rendering (AC-1.7).
@Model
public final class CachedRecipe {

    @Attribute(.unique) public var id: Int
    public var slug: String
    public var title: String
    public var excerptText: String
    public var canonicalURLString: String
    public var heroImageURLString: String?
    public var heroImageLargeURLString: String?
    public var categoryIDs: [Int]
    public var publishedAt: Date

    /// Drives LRU ordering. Updated on every detail open.
    public var lastViewedAt: Date

    /// Pins the row from LRU eviction (NFR-1).
    public var isSaved: Bool

    /// Non-nil once the JSON-LD parse has populated the detail fields.
    public var jsonLDParsedAt: Date?

    /// Non-nil if a detail fetch failed JSON-LD parse — AC-1.7 blocklist signal.
    public var jsonLDFailedAt: Date?

    /// Non-nil once the user has explicitly downloaded this recipe for
    /// offline use (US-35 / AC-35.2 / AC-35.5). Distinct from `isSaved` —
    /// a recipe can be downloaded without being saved, saved without an
    /// explicit download (auto-downloaded per AC-5.2), or both. Pins the
    /// row from LRU eviction the same way `isSaved` does — see
    /// ``RecipeStore.evictIfNeeded()``. Additive optional, lightweight
    /// migration per MIGRATION.md R-5.
    public var downloadedAt: Date?

    // Detail payload — Codable-encoded for flexibility across schema changes.
    public var ingredientsJSON: Data?
    public var instructionsJSON: Data?
    public var nutritionJSON: Data?
    public var videoJSON: Data?
    public var prepSeconds: Int?
    public var cookSeconds: Int?
    public var totalSeconds: Int?
    public var servings: Int?

    public init(
        id: Int,
        slug: String,
        title: String,
        excerptText: String,
        canonicalURLString: String,
        heroImageURLString: String? = nil,
        heroImageLargeURLString: String? = nil,
        categoryIDs: [Int] = [],
        publishedAt: Date,
        lastViewedAt: Date = .now,
        isSaved: Bool = false,
        jsonLDParsedAt: Date? = nil,
        jsonLDFailedAt: Date? = nil,
        downloadedAt: Date? = nil
    ) {
        self.id = id
        self.slug = slug
        self.title = title
        self.excerptText = excerptText
        self.canonicalURLString = canonicalURLString
        self.heroImageURLString = heroImageURLString
        self.heroImageLargeURLString = heroImageLargeURLString
        self.categoryIDs = categoryIDs
        self.publishedAt = publishedAt
        self.lastViewedAt = lastViewedAt
        self.isSaved = isSaved
        self.jsonLDParsedAt = jsonLDParsedAt
        self.jsonLDFailedAt = jsonLDFailedAt
        self.downloadedAt = downloadedAt
    }
}
