import DODSupport
import Foundation

extension RecipeDetailViewModel {

    /// Submit the in-progress comment draft (and the pending rating, if
    /// non-zero). Gated behind the guest-identity sheet. AC-14.3 /
    /// AC-14.4 / AC-14.7.
    ///
    /// Extracted from `RecipeDetailViewModel.swift` (DUT-7) so the parent
    /// file stays under the SwiftLint `file_length` cap of 400 lines after
    /// the author-identity guard landed.
    public func submitComment() async {
        let trimmed = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let identity = await dependencies.loadGuestIdentity() else {
            requiresGuestIdentity = true
            return
        }
        // DUT-7 hypothesis #4 guard: a fresh install (or a partially-saved
        // Keychain row) can hand back an identity whose name or email is
        // empty / whitespace. Posting that yields `author_email=""` → WP
        // returns 400 and the comment silently never lands. Re-gate behind
        // the guest-identity sheet (US-15) instead of firing a doomed POST,
        // and tell the user why. `loadGuestIdentity()` already maps a missing
        // field to `nil`, so this catches the empty-string-default case the
        // Keychain layer cannot.
        let trimmedName = identity.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = identity.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedEmail.isEmpty else {
            DODLog.network.error("comment submit blocked: empty author name/email — re-gating identity")
            requiresGuestIdentity = true
            snackbarMessage = "Add your name and email to post a comment."
            return
        }
        isSubmittingComment = true
        defer { isSubmittingComment = false }

        do {
            let ratingToSend = pendingUserRating > 0 ? pendingUserRating : nil
            let posted = try await dependencies.postComment(
                postID: listItem.id,
                body: trimmed,
                name: trimmedName,
                email: trimmedEmail,
                rating: ratingToSend
            )
            let awaitingApproval = posted.status != .approved
            if !awaitingApproval {
                // Prepend the approved comment so the user sees it land.
                comments.insert(posted, at: 0)
                await dependencies.cacheComments(comments, postID: listItem.id)
                snackbarMessage = "Comment posted."
            } else {
                // AC-14.4: held comments are NOT prepended to the visible
                // list — we only render approved rows.
                snackbarMessage = "Submitted for moderation."
            }
            commentDraft = ""
        } catch {
            DODLog.network.error("post comment failed: \(String(describing: error))")
            snackbarMessage = Self.commentErrorSnackbar(for: error)
        }
    }
}
