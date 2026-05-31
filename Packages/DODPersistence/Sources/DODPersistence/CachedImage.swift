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

    public init(
        urlString: String,
        bytes: Data,
        fetchedAt: Date = .now,
        lastUsedAt: Date = .now,
        pinnedToSavedRecipeID: Int? = nil
    ) {
        self.urlString = urlString
        self.bytes = bytes
        self.fetchedAt = fetchedAt
        self.lastUsedAt = lastUsedAt
        self.pinnedToSavedRecipeID = pinnedToSavedRecipeID
    }
}
