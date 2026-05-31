import Foundation
import SwiftData

/// Local cache of a recipe. Populated in two phases:
/// 1. List-fetch fields written when a `RecipeListItem` first appears in any list.
/// 2. Detail-fetch fields populated after JSON-LD parse on first detail open.
///
/// Cache policies (NFR-1, plan §2):
/// - LRU window: 100 unsaved rows max, oldest `lastViewedAt` evicted first.
/// - `isSaved == true` rows are pinned and never evicted.
/// - `jsonLDFailedAt != nil` rows are **classified as articles** post-T-640
///   (per US-37 / CL-63 / AC-37.4 — the field's semantic was reframed from
///   "blocklisted from list rendering" to "is article, render with
///   HTML body"). Articles are no longer hidden from list queries; the
///   pull-to-refresh `clearBlocklist()` call site is preserved so a
///   server-side JSON-LD fix can re-classify a row back to recipe
///   rendering on the next detail open.
@Model
public final class CachedRecipe {

    // CloudKit mirroring (`cloudKitDatabase: .private`) requires every stored
    // attribute to be optional or carry a default value, else the container
    // fails to open and the app crashes at launch once sync is enabled. These
    // defaults satisfy that at the schema layer; they do NOT change the Core
    // Data version hash (default values aren't hashed), so existing on-disk
    // stores keep opening with no migration. `init` always overwrites them
    // with the real values. (DOD-CRASH-1)
    public var id: Int = 0
    public var slug: String = ""
    public var title: String = ""
    public var excerptText: String = ""
    public var canonicalURLString: String = ""
    public var heroImageURLString: String?
    public var heroImageLargeURLString: String?
    public var categoryIDs: [Int] = []
    public var publishedAt = Date.distantPast

    /// Drives LRU ordering. Updated on every detail open.
    public var lastViewedAt = Date.distantPast

    /// Pins the row from LRU eviction (NFR-1).
    public var isSaved: Bool = false

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

    /// US-37 / CL-63 / AC-37.6 (T-640): sanitized plain-text article body
    /// for posts classified as articles. Nil for recipe rows. Populated
    /// by `RecipeStore.mergeDetail(_:)` from the parsed `Recipe.articleBodyHTML`
    /// field. Lightweight additive optional column — SwiftData migration
    /// from `SchemaV3` is the default in-place migration since the field
    /// is optional with a default of nil.
    public var articleBodyHTML: String?

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
        downloadedAt: Date? = nil,
        articleBodyHTML: String? = nil
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
        self.articleBodyHTML = articleBodyHTML
    }
}
