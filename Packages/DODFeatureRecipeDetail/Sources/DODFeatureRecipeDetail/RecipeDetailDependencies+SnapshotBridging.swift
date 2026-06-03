import DODDomain
import DODPersistence
import Foundation

// Persistence-snapshot ↔ Domain bridging helpers used by
// ``LiveRecipeDetailDependencies`` for the comments cache surface.
//
// Wave-1 sub 3 deliberately kept ``CachedCommentSnapshot`` independent
// of ``RecipeComment`` (timing decoupling); we stitch them together
// here. Extracted from `RecipeDetailDependencies.swift` so that file
// stays under the SwiftLint 400-line `file_length` cap after the
// Phase c profile-gate additions.

extension LiveRecipeDetailDependencies {

    /// Convert the persistence-layer snapshot to the Domain comment type.
    static func snapshotToComment(_ snapshot: CachedCommentSnapshot) -> RecipeComment {
        RecipeComment(
            id: snapshot.id,
            postID: snapshot.postID,
            parentID: snapshot.parentID,
            authorName: snapshot.authorName,
            avatarURL: snapshot.avatarURLString.flatMap { URL(string: $0) },
            dateGMT: snapshot.dateGMT,
            body: snapshot.bodyText,
            ratingValue: snapshot.ratingValue,
            status: RecipeComment.Status(rawValue: snapshot.statusRaw) ?? .unknown
        )
    }

    /// Inverse of ``snapshotToComment(_:)``. `postID` is taken from the
    /// caller because the WP DTO carries it on every row, but the Domain
    /// type also stores it — we trust the caller to pass the same id.
    static func commentToSnapshot(_ comment: RecipeComment, postID: Int) -> CachedCommentSnapshot {
        CachedCommentSnapshot(
            id: comment.id,
            postID: postID,
            parentID: comment.parentID,
            authorName: comment.authorName,
            avatarURLString: comment.avatarURL?.absoluteString,
            dateGMT: comment.dateGMT,
            bodyText: comment.body,
            ratingValue: comment.ratingValue,
            statusRaw: comment.status.rawValue,
            cachedAt: .now,
            isPendingFromThisDevice: false
        )
    }
}
