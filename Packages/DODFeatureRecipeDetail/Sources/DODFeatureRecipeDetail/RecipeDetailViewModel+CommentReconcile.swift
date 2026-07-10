import DODDomain
import Foundation

// DUT-742 — pure, testable reconcile between the freshly-fetched APPROVED
// comments page and this device's local cache (which includes its own
// moderation-held "pending" comment). Lives in its own file so
// `RecipeDetailViewModel+CommentSubmit.swift` stays under the SwiftLint
// 400-line `file_length` cap, and so the data-loss guarantees below have a
// focused home + regression suite.
//
// Two data-loss bugs motivated this:
//
//  * BUG 2 (the critical one): the user's own just-posted comment sits in
//    WordPress's moderation queue (`status == .hold`). The PUBLIC comments
//    GET returns APPROVED rows only, so it never contains the held comment.
//    The previous reconcile deduped the local optimistic/pending copy against
//    the fetched page BY SERVER ID only. When the held POST echoed no usable
//    id (an anonymous, can't-read-own-unapproved-comment POST), or the
//    comment later returned approved under a different id than the moderation
//    -time echo, the id-only match failed and the pending copy was dropped —
//    so the comment (and its rating) VANISHED on the next revisit. It must
//    instead survive until the server returns it approved, then dedupe by
//    CONTENT, not id.
//
//  * BUG 1 tail: WordPress drops `meta.wprm_comment_rating` on REST comment
//    create AND omits it from the public GET, so the approved copy usually
//    comes back rating-less. The star the user attached has to be carried
//    forward from the pending copy or it disappears the moment the comment is
//    approved.
extension RecipeDetailViewModel {

    /// Stable content signature for matching an optimistic/pending comment
    /// against the server's later-approved copy WITHOUT relying on the WP
    /// comment id. Author display name + body are what actually identify
    /// "this is my comment", and both round-trip through the wire and the
    /// local cache. Whitespace-trimmed + case-folded so a trivial echo
    /// difference (a re-cased name, a trailing newline) still matches. The
    /// `\u{1f}` unit separator keeps `name|body` from colliding with a
    /// different `name|body` split at the same boundary.
    static func commentSignature(_ comment: RecipeComment) -> String {
        let charSet = CharacterSet.whitespacesAndNewlines
        let name = comment.authorName.trimmingCharacters(in: charSet).lowercased()
        let body = comment.body.trimmingCharacters(in: charSet).lowercased()
        return name + "\u{1f}" + body
    }

    /// True when `lhs` and `rhs` are the same logical comment — the same WP
    /// id (only when BOTH carry a real, non-zero id) OR the same content
    /// signature. The content match is the load-bearing one: it survives the
    /// id drift / id absence that broke the old id-only dedup (see the file
    /// header). A `0` id (WP's "no id" sentinel, and the persistence model's
    /// default) never matches by id so two distinct un-id'd rows don't
    /// collapse into one on id alone.
    static func isSameComment(_ lhs: RecipeComment, _ rhs: RecipeComment) -> Bool {
        if lhs.id != 0, rhs.id != 0, lhs.id == rhs.id { return true }
        return commentSignature(lhs) == commentSignature(rhs)
    }

    /// Return a copy of `comment` with its `ratingValue` forced to `rating`
    /// (no-op when `rating` is nil). Used to (a) stamp the user's chosen star
    /// onto the optimistic/pending comment WordPress echoes back rating-less,
    /// and (b) carry that star forward onto the now-approved server copy so it
    /// doesn't blink out when the comment is approved.
    static func stampRating(_ comment: RecipeComment, rating: Int?) -> RecipeComment {
        guard let rating else { return comment }
        return RecipeComment(
            id: comment.id,
            postID: comment.postID,
            parentID: comment.parentID,
            authorName: comment.authorName,
            authorEmail: comment.authorEmail,
            avatarURL: comment.avatarURL,
            dateGMT: comment.dateGMT,
            body: comment.body,
            ratingValue: rating,
            status: comment.status
        )
    }

    /// Reconcile the freshly-fetched APPROVED page against what this device
    /// has cached (which includes its own still-pending, moderation-held
    /// comment). Returns the list to DISPLAY and the list to CACHE as public
    /// rows.
    ///
    /// Guarantees (see the file header for the bugs these close):
    ///   * a still-pending own-comment the approved page does NOT contain is
    ///     KEPT — never clobbered by the approved-only fetch;
    ///   * when that comment finally returns approved it dedupes by CONTENT
    ///     (or id when both ids are real), so it neither duplicates nor vanishes;
    ///   * the star rating the user attached survives the flip to approved —
    ///     it is carried forward from the pending copy when the server copy
    ///     came back rating-less.
    static func reconcileComments(
        approved: [RecipeComment],
        cached: [RecipeComment]
    ) -> (visible: [RecipeComment], toCache: [RecipeComment]) {
        let pending = cached.filter { $0.status != .approved }
        // Carry a pending copy's rating onto its now-approved twin when the
        // server copy lost the star (the common case — WP drops the comment
        // rating meta on create + omits it from the GET).
        let mergedApproved = approved.map { serverCopy -> RecipeComment in
            guard serverCopy.ratingValue == nil,
                let twin = pending.first(where: { isSameComment($0, serverCopy) }),
                let rating = twin.ratingValue
            else { return serverCopy }
            return stampRating(serverCopy, rating: rating)
        }
        // Keep only the pending rows the approved page did NOT supersede.
        let stillPending = pending.filter { pendingRow in
            !approved.contains { isSameComment($0, pendingRow) }
        }
        return (visible: mergedApproved + stillPending, toCache: mergedApproved)
    }
}
