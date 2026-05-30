import Foundation
import SwiftData

/// Persistent state for a single paginated list. Keyed by list identity:
/// - `"home"` for the home feed
/// - `"category:<id>"` for a category list
/// - `"search:<hash>"` for a search result
///
/// Used by Feed/Category/Search view models so list state survives app
/// relaunch and supports offline hydration (AC-1.6).
@Model
public final class CachedListPage {

    public var key: String
    public var pageNumber: Int
    public var recipeIDs: [Int]
    public var fetchedAt: Date

    public init(key: String, pageNumber: Int, recipeIDs: [Int], fetchedAt: Date = .now) {
        self.key = key
        self.pageNumber = pageNumber
        self.recipeIDs = recipeIDs
        self.fetchedAt = fetchedAt
    }
}
