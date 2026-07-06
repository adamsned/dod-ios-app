#if canImport(UIKit)
import AuthenticationServices
import Foundation
import Testing

@testable import DODFeatureProfile

/// DUT-636 — L1 for ``AppleProfileSignInButton``'s failure classification. A
/// user-initiated cancel (or an `.unknown` dismissal) stays silent (`nil`); a
/// real failure surfaces a user-facing message the host shows via `saveError`.
/// UIKit-gated because `ASAuthorizationError` only exists where SiwA does.
@Suite("AppleProfileSignInButton error classification (DUT-636)")
struct AppleProfileSignInButtonErrorTests {

    private func error(_ code: ASAuthorizationError.Code) -> ASAuthorizationError {
        ASAuthorizationError(code)
    }

    @Test func cancellationStaysSilent() {
        #expect(AppleProfileSignInButton.userFacingErrorMessage(for: error(.canceled)) == nil)
    }

    @Test func unknownStaysSilent() {
        // Some OS versions report a user dismissal as `.unknown`; don't nag.
        #expect(AppleProfileSignInButton.userFacingErrorMessage(for: error(.unknown)) == nil)
    }

    @Test func realFailureSurfacesAMessage() {
        #expect(AppleProfileSignInButton.userFacingErrorMessage(for: error(.failed)) != nil)
        #expect(AppleProfileSignInButton.userFacingErrorMessage(for: error(.invalidResponse)) != nil)
        #expect(AppleProfileSignInButton.userFacingErrorMessage(for: error(.notHandled)) != nil)
    }

    @Test func nonAuthorizationErrorSurfacesAMessage() {
        struct Boom: Error {}
        #expect(AppleProfileSignInButton.userFacingErrorMessage(for: Boom()) != nil)
    }
}
#endif
