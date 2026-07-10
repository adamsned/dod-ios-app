import DODNetworking
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// REG-27 / US-14 (round-9 backlog hypothesis H1): the comment-POST failure
/// path surfaces a category-specific snackbar so a TestFlight reporter
/// (or dad on his real device) can read the chip and tell us which class of
/// failure occurred. Before REG-27 every error collapsed to a single
/// "Couldn't post your comment — try again." which made remote diagnosis
/// impossible.
///
/// Spec trace: REG-27 in `spec.md`; CL-108 in `clarifications.md`.
@Suite("RecipeDetailViewModel.commentErrorSnackbar (REG-27 / US-14)")
struct CommentErrorSnackbarTests {

    @Test func networkUnavailableSurfacesOfflineMessage() {
        let snackbar = RecipeDetailViewModel.commentErrorSnackbar(
            for: WPClientError.networkUnavailable
        )
        #expect(snackbar == "You're offline. Reconnect and try again.")
    }

    @Test func timeoutSurfacesServerTookTooLongMessage() {
        let snackbar = RecipeDetailViewModel.commentErrorSnackbar(
            for: WPClientError.timeout
        )
        #expect(snackbar == "The server took too long. Try again.")
    }

    @Test func httpStatusSurfacesServerSaidStatusCode() {
        let snackbar = RecipeDetailViewModel.commentErrorSnackbar(
            for: WPClientError.httpStatus(403)
        )
        #expect(snackbar == "Couldn't post your comment (server said 403).")
    }

    /// DUT-27 (build 8): a bare 409 is WordPress's duplicate verdict. Show the
    /// friendly "already posted" line, not "server said 409", so the user
    /// stops re-submitting a comment that already reached moderation.
    @Test func bareHTTPStatus409SurfacesDuplicateFriendlyMessage() {
        let snackbar = RecipeDetailViewModel.commentErrorSnackbar(
            for: WPClientError.httpStatus(409)
        )
        #expect(snackbar == "Looks like you already posted this. It may be awaiting approval.")
    }

    /// DUT-27 (build 8): the exact shape from the report — a 409 carrying the
    /// WordPress "Duplicate comment detected …" message. The raw server text
    /// is replaced with the friendly duplicate line rather than surfaced.
    @Test func httpStatus409WithBodySurfacesDuplicateFriendlyMessage() {
        let snackbar = RecipeDetailViewModel.commentErrorSnackbar(
            for: WPClientError.httpStatusWithBody(
                409,
                message: "Duplicate comment detected; it looks as though you\u{2019}ve already said that!"
            )
        )
        #expect(snackbar == "Looks like you already posted this. It may be awaiting approval.")
    }

    /// DUT-7 / AC-14.4: when WordPress hands back a reason, the snackbar
    /// surfaces the code AND the message — not just the number — so the
    /// user (and a TestFlight reporter reading the chip) sees *why* it failed.
    @Test func httpStatusWithBodySurfacesCodeAndServerMessage() {
        let snackbar = RecipeDetailViewModel.commentErrorSnackbar(
            for: WPClientError.httpStatusWithBody(400, message: "Comment content is invalid.")
        )
        #expect(snackbar == "Couldn't post your comment (server said 400): Comment content is invalid.")
    }

    @Test func decodingSurfacesReplyMessage() {
        let snackbar = RecipeDetailViewModel.commentErrorSnackbar(
            for: WPClientError.decoding(message: "bad JSON")
        )
        #expect(snackbar == "Couldn't read the server's reply. Try again.")
    }

    @Test func underlyingSurfacesGenericMessage() {
        let snackbar = RecipeDetailViewModel.commentErrorSnackbar(
            for: WPClientError.underlying(message: "anything")
        )
        #expect(snackbar == "Couldn't post your comment. Try again.")
    }

    @Test func nonWPErrorIsWrappedThenMapped() {
        // A raw URLError (not pre-wrapped) gets coerced through
        // WPClientError.wrap then mapped — proves the safety net.
        let urlError = URLError(.notConnectedToInternet)
        let snackbar = RecipeDetailViewModel.commentErrorSnackbar(for: urlError)
        #expect(snackbar == "You're offline. Reconnect and try again.")
    }
}
