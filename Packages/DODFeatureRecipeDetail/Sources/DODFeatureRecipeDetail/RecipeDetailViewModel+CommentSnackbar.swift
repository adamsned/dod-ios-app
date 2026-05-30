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
            return "Couldn't post your comment (server said \(code))."
        case .decoding:
            return "Couldn't read the server's reply — try again."
        case .underlying:
            return "Couldn't post your comment — try again."
        }
    }
}
