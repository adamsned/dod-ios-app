import Foundation
import SwiftData

/// Disk-cached image bytes. Cap: 200 MB across all rows (NFR-2).
///
/// Rows referenced by a saved recipe (`pinnedToSavedRecipeID != nil`) are
/// excluded from LRU eviction so saved recipes stay viewable offline.
@Model
public final class CachedImage {

    // CloudKit needs every attribute optional-or-defaulted (DOD-CRASH-1);
    // defaults don't change the schema hash and `init` overwrites them.
    public var urlString: String = ""
    public var bytes = Data()
    public var fetchedAt = Date.distantPast
    public var lastUsedAt = Date.distantPast
    public var pinnedToSavedRecipeID: Int?
    /// DUT-242: a cheap, denormalized copy of `bytes.count`. Eviction +
    /// clear-cache sum this scalar (via `propertiesToFetch`) instead of reading
    /// `bytes.count` over every row, which faulted every image's full payload
    /// into RAM on every scroll. Defaulted (in-place migration); set on every
    /// write; pre-existing rows are backfilled once (see `RecipeStore`).
    public var byteCount: Int = 0

    public init(
        urlString: String,
        bytes: Data,
        fetchedAt: Date = .now,
        lastUsedAt: Date = .now,
        pinnedToSavedRecipeID: Int? = nil
    ) {
        self.urlString = urlString
        self.bytes = bytes
        self.byteCount = bytes.count
        self.fetchedAt = fetchedAt
        self.lastUsedAt = lastUsedAt
        self.pinnedToSavedRecipeID = pinnedToSavedRecipeID
    }
}
