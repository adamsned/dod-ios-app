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
        #expect(snackbar == "You're offline — comment will need to wait.")
    }

    @Test func timeoutSurfacesServerTookTooLongMessage() {
        let snackbar = RecipeDetailViewModel.commentErrorSnackbar(
            for: WPClientError.timeout
        )
        #expect(snackbar == "The server took too long — try again.")
    }

    @Test func httpStatusSurfacesServerSaidStatusCode() {
        let snackbar = RecipeDetailViewModel.commentErrorSnackbar(
            for: WPClientError.httpStatus(403)
        )
        #expect(snackbar == "Couldn't post your comment (server said 403).")
    }

    @Test func decodingSurfacesReplyMessage() {
        let snackbar = RecipeDetailViewModel.commentErrorSnackbar(
            for: WPClientError.decoding(message: "bad JSON")
        )
        #expect(snackbar == "Couldn't read the server's reply — try again.")
    }

    @Test func underlyingSurfacesGenericMessage() {
        let snackbar = RecipeDetailViewModel.commentErrorSnackbar(
            for: WPClientError.underlying(message: "anything")
        )
        #expect(snackbar == "Couldn't post your comment — try again.")
    }

    @Test func nonWPErrorIsWrappedThenMapped() {
        // A raw URLError (not pre-wrapped) gets coerced through
        // WPClientError.wrap then mapped — proves the safety net.
        let urlError = URLError(.notConnectedToInternet)
        let snackbar = RecipeDetailViewModel.commentErrorSnackbar(for: urlError)
        #expect(snackbar == "You're offline — comment will need to wait.")
    }
}
