import DODSupport
import Foundation

extension RecipeDetailViewModel {

    /// DUT-981 — post a guest's praise as a public comment/review. Posted
    /// under the HOST's identity (WP needs a valid author email; guests give
    /// none), with the guest attributed in the body. Returns true on success.
    /// Never touches `commentDraft` or `pendingUserRating`.
    @discardableResult
    public func submitGuestReaction(quote: String, guestName: String, rating: Int?) async -> Bool {
        let name = commentAuthorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = commentAuthorEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !email.isEmpty else {
            snackbarMessage = "Add your name and email to post a comment."
            return false
        }
        guard
            let body = GuestReactionFormatter.commentBody(
                quote: quote,
                guestName: guestName,
                hostName: name
            )
        else { return false }
        let stars = rating.map { min(5, max(1, $0)) }
        do {
            let posted = try await dependencies.postComment(
                postID: listItem.id,
                body: body,
                name: name,
                email: email,
                rating: stars
            )
            let stamped = Self.stampRating(
                Self.stampAuthorEmail(posted, email: email),
                rating: stars
            )
            insertPostedCommentIfNew(stamped)
            if stamped.status == .approved {
                await dependencies.cacheComments(comments, postID: listItem.id)
                snackbarMessage = "Review posted."
            } else {
                await dependencies.cachePendingComment(stamped, postID: listItem.id)
                snackbarMessage = "Review submitted. It will appear after approval."
            }
            return true
        } catch {
            DODLog.network.error("guest reaction post failed: \(String(describing: error))")
            snackbarMessage = Self.commentErrorSnackbar(for: error)
            return false
        }
    }
}
