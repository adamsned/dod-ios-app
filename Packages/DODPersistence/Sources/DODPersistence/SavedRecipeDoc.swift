import Foundation

/// One saved recipe as stored in Firestore at `users/{uid}/saved/{id}`, the
/// shape the Android app reads and writes (`SavedRecipeDoc.kt`), so a save on
/// either platform shows up on the other for the same Firebase user.
public struct SavedRecipeDoc: Sendable, Equatable {
    public var id: Int
    public var title: String
    public var excerpt: String
    public var imageURL: String?
    public var canonicalURL: String
    /// ISO-8601, or "" when unknown (Android reads only the first 10 characters).
    public var publishedDate: String
    public var totalTimeMinutes: Int?
    public var savedAtEpochMs: Int64
    public var isArticle: Bool

    /// The Firestore field map. Keys and `kind` values must match Android.
    public var fields: [String: Any] {
        var map: [String: Any] = [
            "id": id,
            "title": title,
            "excerpt": excerpt,
            "canonicalUrl": canonicalURL,
            "publishedDate": publishedDate,
            "savedAtEpochMs": savedAtEpochMs,
            "kind": isArticle ? "ARTICLE" : "RECIPE",
        ]
        map["imageUrl"] = imageURL ?? NSNull()
        map["totalTimeMinutes"] = totalTimeMinutes ?? NSNull()
        return map
    }

    /// Reads a Firestore field map; `nil` when a required field is missing or malformed.
    public init?(fields: [String: Any]) {
        guard
            let id = (fields["id"] as? NSNumber)?.intValue,
            let savedAt = (fields["savedAtEpochMs"] as? NSNumber)?.int64Value,
            let title = fields["title"] as? String,
            let canonicalURL = fields["canonicalUrl"] as? String
        else { return nil }
        self.id = id
        self.title = title
        self.excerpt = fields["excerpt"] as? String ?? ""
        self.imageURL = fields["imageUrl"] as? String
        self.canonicalURL = canonicalURL
        self.publishedDate = fields["publishedDate"] as? String ?? ""
        self.totalTimeMinutes = (fields["totalTimeMinutes"] as? NSNumber)?.intValue
        self.savedAtEpochMs = savedAt
        self.isArticle = fields["kind"] as? String == "ARTICLE"
    }

    init(_ row: SyncedSavedRecipe) {
        id = row.id
        title = row.title
        excerpt = row.excerptText
        imageURL = row.heroImageURLString
        canonicalURL = row.canonicalURLString
        publishedDate =
            row.publishedAt == .distantPast ? "" : row.publishedAt.formatted(.iso8601)
        totalTimeMinutes = row.totalSeconds.map { $0 / 60 }
        savedAtEpochMs = Int64((row.savedAt.timeIntervalSince1970 * 1000).rounded())
        isArticle = row.isArticle
    }

    var savedAt: Date { Date(timeIntervalSince1970: Double(savedAtEpochMs) / 1000) }

    /// Android writes WordPress dates without a zone ("2026-05-01T10:00:00"); read those as UTC.
    var publishedAt: Date {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: publishedDate) ?? iso.date(from: publishedDate + "Z") {
            return date
        }
        iso.formatOptions = [.withFullDate]
        return iso.date(from: String(publishedDate.prefix(10))) ?? .distantPast
    }
}

/// Receives this device's own saves and removals so they can be written to the
/// cross-platform store. Remote changes applied through
/// ``RecipeStore/applyRemoteSaved(_:)`` and ``RecipeStore/applyRemoteRemoval(id:)``
/// do not come back through here.
public protocol SavedRecipeMirror: Sendable {
    func saved(_ doc: SavedRecipeDoc)
    func removed(id: Int)
}
