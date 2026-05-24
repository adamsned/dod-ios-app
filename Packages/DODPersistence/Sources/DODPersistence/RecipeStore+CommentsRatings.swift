import Foundation
import SwiftData

/// US-13 / US-14 comment + rating cache methods on `RecipeStore`. Lives in
/// its own file so the main store stays under the SwiftLint file-length
/// budget (constitution §10).
///
/// **Design note (TIMING constraint).** This branch lands in parallel with
/// `feat/comments-data`, which owns `DODDomain.RecipeComment` and
/// `DODDomain.RecipeRating`. To avoid a circular wait, the accessors here
/// take/return primitive `CachedCommentSnapshot` / `CachedRatingSnapshot`
/// value types defined in this package — sub 2 (data) will add Domain-typed
/// convenience wrappers once their types land on `main`. The `@Model`
/// classes themselves never reference the Domain types, so the persistence
/// schema is fully isolated from the Domain branch's merge order.
extension RecipeStore {

    // MARK: - Comments (US-14)

    /// Insert-or-update a batch of comments freshly fetched from WP.
    /// Existing rows with the same `id` are overwritten in place — useful
    /// when WP's `status` flips from `hold` to `approved` between fetches.
    /// Does **not** clear pending rows; those are owned by
    /// ``upsertPendingComment(_:)`` / ``deletePendingComment(id:)``.
    public func cacheComments(_ comments: [CachedCommentSnapshot]) throws {
        for snapshot in comments {
            try upsertComment(snapshot)
        }
        try modelContext.save()
    }

    /// Read back the cached comments for one post.
    ///
    /// Ordering rule (US-14): approved-or-otherwise-public rows come back
    /// **newest first** by `dateGMT`, then any `isPendingFromThisDevice`
    /// rows are appended at the end (still newest-pending-first). Pending
    /// rows are surfaced to the author only — public reader UI filters
    /// them out before display, but this store returns the full set so the
    /// view layer can branch on `isPendingFromThisDevice` per row.
    public func cachedComments(forPostID id: Int) throws -> [CachedCommentSnapshot] {
        let descriptor = FetchDescriptor<CachedComment>(
            predicate: #Predicate { row in row.postID == id },
            sortBy: [SortDescriptor(\.dateGMT, order: .reverse)]
        )
        let rows = try modelContext.fetch(descriptor)
        let approved = rows.filter { !$0.isPendingFromThisDevice }
        let pending = rows.filter { $0.isPendingFromThisDevice }
        return (approved + pending).map(Self.toSnapshot)
    }

    /// Insert (or update) a comment row that THIS device just submitted
    /// and that WP returned with status `hold`. The author sees it in the
    /// thread with an "Awaiting approval" label until either a fresh fetch
    /// returns it with status `approved` (and `cacheComments` overwrites
    /// it with `isPendingFromThisDevice = false`) or the user dismisses /
    /// retries.
    public func upsertPendingComment(_ comment: CachedCommentSnapshot) throws {
        var pending = comment
        pending.isPendingFromThisDevice = true
        try upsertComment(pending)
        try modelContext.save()
    }

    /// Remove a pending row by id. Called when the user retracts a
    /// pending comment or when WP confirms it as `approved` (the
    /// confirmation path goes through `cacheComments` and the row's
    /// `isPendingFromThisDevice` is reset to `false`, so this is only the
    /// explicit-delete path).
    public func deletePendingComment(id: Int) throws {
        let descriptor = FetchDescriptor<CachedComment>(
            predicate: #Predicate { row in
                row.id == id && row.isPendingFromThisDevice == true
            }
        )
        for row in try modelContext.fetch(descriptor) {
            modelContext.delete(row)
        }
        try modelContext.save()
    }

    // MARK: - Ratings (US-13)

    /// Insert-or-update the cached aggregate rating for one recipe.
    /// Preserves any existing `userRating` value — it's only overwritten
    /// when the snapshot explicitly carries a non-nil `userRating` (call
    /// sites that only fetch the aggregate should leave it `nil`).
    public func cacheRating(_ rating: CachedRatingSnapshot) throws {
        if let existing = try fetchRating(forRecipeID: rating.recipeID) {
            existing.average = rating.average
            existing.count = rating.count
            if let newUserRating = rating.userRating {
                existing.userRating = newUserRating
            }
            existing.cachedAt = .now
        } else {
            modelContext.insert(
                CachedRating(
                    recipeID: rating.recipeID,
                    average: rating.average,
                    count: rating.count,
                    userRating: rating.userRating
                )
            )
        }
        try modelContext.save()
    }

    /// Read back the cached rating for one recipe, or `nil` if absent.
    public func cachedRating(forRecipeID id: Int) throws -> CachedRatingSnapshot? {
        try fetchRating(forRecipeID: id).map(Self.toSnapshot)
    }

    /// Set THIS device's user-rating value for a recipe without touching
    /// the aggregate fields. Used after the rating sheet posts a 1–5 star
    /// value to WP — the aggregate updates on the next refresh.
    /// If no rating row exists yet, creates one with `average = 0, count = 0`.
    public func setUserRating(_ stars: Int, forRecipeID id: Int) throws {
        if let existing = try fetchRating(forRecipeID: id) {
            existing.userRating = stars
            existing.cachedAt = .now
        } else {
            modelContext.insert(
                CachedRating(recipeID: id, average: 0, count: 0, userRating: stars)
            )
        }
        try modelContext.save()
    }

    // MARK: - Private helpers

    private func upsertComment(_ snapshot: CachedCommentSnapshot) throws {
        let id = snapshot.id
        let descriptor = FetchDescriptor<CachedComment>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.postID = snapshot.postID
            existing.parentID = snapshot.parentID
            existing.authorName = snapshot.authorName
            existing.avatarURLString = snapshot.avatarURLString
            existing.dateGMT = snapshot.dateGMT
            existing.bodyText = snapshot.bodyText
            existing.ratingValue = snapshot.ratingValue
            existing.statusRaw = snapshot.statusRaw
            existing.cachedAt = .now
            existing.isPendingFromThisDevice = snapshot.isPendingFromThisDevice
        } else {
            modelContext.insert(
                CachedComment(
                    id: snapshot.id,
                    postID: snapshot.postID,
                    parentID: snapshot.parentID,
                    authorName: snapshot.authorName,
                    avatarURLString: snapshot.avatarURLString,
                    dateGMT: snapshot.dateGMT,
                    bodyText: snapshot.bodyText,
                    ratingValue: snapshot.ratingValue,
                    statusRaw: snapshot.statusRaw,
                    cachedAt: .now,
                    isPendingFromThisDevice: snapshot.isPendingFromThisDevice
                )
            )
        }
    }

    private func fetchRating(forRecipeID id: Int) throws -> CachedRating? {
        let descriptor = FetchDescriptor<CachedRating>(
            predicate: #Predicate { $0.recipeID == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    static func toSnapshot(_ row: CachedComment) -> CachedCommentSnapshot {
        CachedCommentSnapshot(
            id: row.id,
            postID: row.postID,
            parentID: row.parentID,
            authorName: row.authorName,
            avatarURLString: row.avatarURLString,
            dateGMT: row.dateGMT,
            bodyText: row.bodyText,
            ratingValue: row.ratingValue,
            statusRaw: row.statusRaw,
            cachedAt: row.cachedAt,
            isPendingFromThisDevice: row.isPendingFromThisDevice
        )
    }

    static func toSnapshot(_ row: CachedRating) -> CachedRatingSnapshot {
        CachedRatingSnapshot(
            recipeID: row.recipeID,
            average: row.average,
            count: row.count,
            userRating: row.userRating,
            cachedAt: row.cachedAt
        )
    }
}

// MARK: - Snapshot value types

/// Sendable, context-free view of one `CachedComment` row.
///
/// Exists because SwiftData `@Model` instances are bound to a
/// `ModelContext` and can't safely cross actor boundaries. The accessor
/// surface uses this struct instead so callers don't need a
/// `ModelContext` reference. Sub 2 (`feat/comments-data`) will add
/// `DODDomain.RecipeComment` and bridge it to/from this snapshot once
/// both branches are on `main`.
public struct CachedCommentSnapshot: Sendable, Hashable {

    public var id: Int
    public var postID: Int
    public var parentID: Int?
    public var authorName: String
    public var avatarURLString: String?
    public var dateGMT: Date
    public var bodyText: String
    public var ratingValue: Int?
    public var statusRaw: String
    public var cachedAt: Date
    public var isPendingFromThisDevice: Bool

    public init(
        id: Int,
        postID: Int,
        parentID: Int? = nil,
        authorName: String,
        avatarURLString: String? = nil,
        dateGMT: Date,
        bodyText: String,
        ratingValue: Int? = nil,
        statusRaw: String,
        cachedAt: Date = .now,
        isPendingFromThisDevice: Bool = false
    ) {
        self.id = id
        self.postID = postID
        self.parentID = parentID
        self.authorName = authorName
        self.avatarURLString = avatarURLString
        self.dateGMT = dateGMT
        self.bodyText = bodyText
        self.ratingValue = ratingValue
        self.statusRaw = statusRaw
        self.cachedAt = cachedAt
        self.isPendingFromThisDevice = isPendingFromThisDevice
    }
}

/// Sendable, context-free view of one `CachedRating` row. Same rationale
/// as ``CachedCommentSnapshot``.
public struct CachedRatingSnapshot: Sendable, Hashable {

    public var recipeID: Int
    public var average: Double
    public var count: Int
    public var userRating: Int?
    public var cachedAt: Date

    public init(
        recipeID: Int,
        average: Double,
        count: Int,
        userRating: Int? = nil,
        cachedAt: Date = .now
    ) {
        self.recipeID = recipeID
        self.average = average
        self.count = count
        self.userRating = userRating
        self.cachedAt = cachedAt
    }
}
