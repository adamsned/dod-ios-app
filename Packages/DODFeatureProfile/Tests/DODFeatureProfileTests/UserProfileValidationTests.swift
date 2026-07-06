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

    // DUT-647 — length cap, symmetric with the guest/comment path's
    // `GuestIdentitySheet.isValidName` 1–40 window.

    @Test func displayNameAcceptsExactlyMaxLength() throws {
        let atCap = String(repeating: "a", count: UserProfile.maxDisplayNameLength)
        #expect(try UserProfile.validateDisplayName(atCap) == atCap)
    }

    @Test func displayNameRejectsOverMaxLength() throws {
        let overCap = String(repeating: "a", count: UserProfile.maxDisplayNameLength + 1)
        #expect(throws: UserProfile.ValidationError.displayNameTooLong) {
            _ = try UserProfile.validateDisplayName(overCap)
        }
    }

    @Test func displayNameMeasuresLengthAfterTrimming() throws {
        // Trailing whitespace that pushes raw length past the cap is trimmed
        // first, so a name that's <= cap after trimming still passes.
        let atCap = String(repeating: "a", count: UserProfile.maxDisplayNameLength)
        #expect(try UserProfile.validateDisplayName(atCap + "   ") == atCap)
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

    // DUT-647 — the shape `^[^@\s]+@[^@\s]+\.[^@\s]+$` must reject the inputs the
    // old lax guest-path check (`contains("@") && contains(".")`) let through.
    // These pin the canonical rule that `GuestIdentitySheet.isValidEmail` now
    // mirrors byte-for-byte.

    @Test func emailRejectsDotBeforeAtWithNoDomainDot() throws {
        // "a.b@c" — has a dot and an @, but the dot is in the LOCAL part and the
        // domain half carries none. The old guest check wrongly accepted it.
        #expect(throws: UserProfile.ValidationError.emailInvalid) {
            _ = try UserProfile.validateEmail("a.b@c")
        }
    }

    @Test func emailRejectsEmptyLocalPart() throws {
        // "@.com" — empty local part.
        #expect(throws: UserProfile.ValidationError.emailInvalid) {
            _ = try UserProfile.validateEmail("@.com")
        }
    }

    @Test func emailRejectsEmptyDomainHead() throws {
        // "foo@.com" — the domain head (before the dot) is empty.
        #expect(throws: UserProfile.ValidationError.emailInvalid) {
            _ = try UserProfile.validateEmail("foo@.com")
        }
    }
}
