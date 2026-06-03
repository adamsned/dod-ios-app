import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 coverage for ``UserProfile``'s validation helpers — the
/// `validateDisplayName(_:)` non-empty guard and the
/// `validateEmail(_:)` regex shape. Pinning these is load-bearing for
/// the edit form's Done-button gate and the network backstop on the
/// comment path (CL-134 / DUT-7 pattern).
///
/// Spec trace: US-44 AC-44.2; CL-136.
@Suite("UserProfile validation (T-739)")
struct UserProfileValidationTests {

    // MARK: - Display name

    @Test func displayNameRejectsEmpty() throws {
        #expect(throws: UserProfile.ValidationError.displayNameEmpty) {
            _ = try UserProfile.validateDisplayName("")
        }
    }

    @Test func displayNameRejectsWhitespaceOnly() throws {
        #expect(throws: UserProfile.ValidationError.displayNameEmpty) {
            _ = try UserProfile.validateDisplayName("   \t  ")
        }
    }

    @Test func displayNameTrimsAndAcceptsValid() throws {
        let result = try UserProfile.validateDisplayName("  Spencer Adams  ")
        #expect(result == "Spencer Adams")
    }

    // MARK: - Email

    @Test func emailRejectsEmpty() throws {
        #expect(throws: UserProfile.ValidationError.emailEmpty) {
            _ = try UserProfile.validateEmail("")
        }
    }

    @Test func emailRejectsMissingAt() throws {
        #expect(throws: UserProfile.ValidationError.emailInvalid) {
            _ = try UserProfile.validateEmail("noatsign.example.com")
        }
    }

    @Test func emailRejectsMissingDomainDot() throws {
        #expect(throws: UserProfile.ValidationError.emailInvalid) {
            _ = try UserProfile.validateEmail("foo@example")
        }
    }

    @Test func emailRejectsWhitespaceInside() throws {
        #expect(throws: UserProfile.ValidationError.emailInvalid) {
            _ = try UserProfile.validateEmail("foo bar@example.com")
        }
    }

    @Test func emailAcceptsWellFormed() throws {
        let result = try UserProfile.validateEmail("spencer@example.com")
        #expect(result == "spencer@example.com")
    }

    @Test func emailTrimsLeadingTrailingWhitespace() throws {
        let result = try UserProfile.validateEmail("  spencer@example.com  ")
        #expect(result == "spencer@example.com")
    }

    @Test func emailAcceptsSubdomainAndPlusTag() throws {
        let result = try UserProfile.validateEmail("dad+app@mail.dutchovendaddy.com")
        #expect(result == "dad+app@mail.dutchovendaddy.com")
    }
}
