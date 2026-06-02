import DODNetworking
import Foundation

extension RecipeDetailViewModel {

    /// Translate a thrown comment-POST error into a user-visible snackbar
    /// string that **distinguishes the failure category** so a TestFlight
    /// reporter (or @adamsned on his iPhone) can read the chip and tell us
    /// which of the round-9 backlog hypotheses fired. Before REG-27 every
    /// failure surfaced the same "Couldn't post your comment — try again."
    /// message, which collapsed offline / timeout / 4xx / 5xx into one
    /// bucket and made remote diagnosis impossible.
    ///
    /// `nonisolated` so the value-mapping function can be called from
    /// non-`@MainActor` test contexts without requiring an `await`.
    ///
    /// Spec trace: REG-27 in `spec.md`; CL-108 in `clarifications.md`.
    /// Hosted in this extension file (not the main `RecipeDetailViewModel.swift`)
    /// so the parent file stays under the SwiftLint `file_length` cap of 400
    /// lines.
    nonisolated static func commentErrorSnackbar(for error: Error) -> String {
        let wpError = (error as? WPClientError) ?? WPClientError.wrap(error)
        switch wpError {
        case .networkUnavailable:
            return "You're offline — comment will need to wait."
        case .timeout:
            return "The server took too long — try again."
        case .httpStatus(let code):
            // DUT-27: a bare 409 on this path is WordPress's duplicate-comment
            // verdict (the first post already landed and is in moderation).
            // Reassure rather than alarm — the user's comment is not lost.
            if code == 409 { return Self.duplicateCommentSnackbar }
            return "Couldn't post your comment (server said \(code))."
        case .httpStatusWithBody(let code, let message):
            // DUT-27: the build-8 report — WordPress returns the duplicate as a
            // 409 carrying "Duplicate comment detected; it looks as though
            // you've already said that!". Swap that raw "server said 409: ..."
            // text for a friendly line; the original post is already awaiting
            // approval, so this is reassurance, not an error to act on.
            if code == 409 { return Self.duplicateCommentSnackbar }
            // DUT-7 / AC-14.4: any other status with a server reason
            // (moderation rejection, spam verdict, missing field, blocked UA).
            // Surface it after the code so the user — and a TestFlight reporter
            // reading the chip — sees *why*, not just the number. The body is
            // already tag-stripped AND entity-decoded in WPCommentsClient
            // (DUT-27), so no raw "&#8217;" leaks into the chip.
            return "Couldn't post your comment (server said \(code)): \(message)"
        case .decoding:
            return "Couldn't read the server's reply — try again."
        case .underlying:
            return "Couldn't post your comment — try again."
        }
    }

    /// Friendly copy for the WordPress duplicate-comment verdict (HTTP 409).
    /// The first identical comment already reached the moderation queue, so
    /// the goal is to stop the user re-submitting, not to flag a failure.
    /// DUT-27.
    nonisolated static let duplicateCommentSnackbar =
        "Looks like you already posted this — it may be awaiting approval."
}
