import DODSupport
import Foundation

// US-13/14/15 — the standalone `submitRating(stars:)` mutation path.
// Extracted from `RecipeDetailViewModel.swift` so that file stays
// under the SwiftLint 400-line `file_length` cap after the Phase c
// (T-741 / CL-138) profile-gate additions.
//
// Pairs with the existing `RecipeDetailViewModel+CommentSubmit.swift`
// extraction — the combined "rate + post comment in one tap" path
// lives there as `submitRatingAndComment()`. This file owns the
// rating-only mutation (the "Submit rating" tap with no comment text).

extension RecipeDetailViewModel {

    /// Submit a star rating using the on-form author identity. DUT-28:
    /// callers validate name + email first (``canSubmitRatingOrComment``)
    /// and persist the identity, so this path trusts the trimmed values it
    /// is handed. AC-13.2 / AC-13.3 / AC-13.5.
    public func submitRating(stars: Int) async {
        guard (1...5).contains(stars) else { return }
        let name = commentAuthorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = commentAuthorEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !email.isEmpty else {
            snackbarMessage = "Add your name and email to rate this recipe."
            return
        }
        isSubmittingRating = true
        defer { isSubmittingRating = false }

        do {
            let updated = try await dependencies.postRating(
                recipeID: listItem.id,
                stars: stars,
                name: name,
                email: email
            )
            ratingSummary = updated
            pendingUserRating = stars
            await dependencies.cacheRatingSummary(updated)
            snackbarMessage = "Thanks for rating."
        } catch {
            DODLog.network.error("post rating failed: \(String(describing: error))")
            snackbarMessage = "Couldn't save your rating — try again."
        }
    }
}
