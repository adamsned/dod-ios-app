import Foundation
import Testing

@testable import DODSupport

/// L1 coverage for ``AppleCredentialResolver`` — the pure name-formatting +
/// first-auth-only merge logic behind the Sign in with Apple coordinator
/// (US-46 / AC-46.2). These pin the correctness-critical "Apple releases
/// name + email only once" behavior without `AuthenticationServices`.
@Suite("AppleCredentialResolver (US-46)")
struct AppleCredentialResolverTests {

    // MARK: - displayName(from:)

    @Test func formatsGivenAndFamilyName() {
        var components = PersonNameComponents()
        components.givenName = "Ned"
        components.familyName = "Adams"
        #expect(AppleCredentialResolver.displayName(from: components) == "Ned Adams")
    }

    @Test func nilComponentsYieldNilName() {
        #expect(AppleCredentialResolver.displayName(from: nil) == nil)
    }

    @Test func emptyComponentsYieldNilName() {
        // Apple hands back empty components (not nil) on re-auth — must collapse
        // to nil so the caller treats it as "no name this time".
        #expect(AppleCredentialResolver.displayName(from: PersonNameComponents()) == nil)
    }

    // MARK: - resolve(...)

    @Test func firstAuthStoresCredentialNameAndEmail() {
        let session = AppleCredentialResolver.resolve(
            userIdentifier: "user-1",
            credentialDisplayName: "Ned Adams",
            credentialEmail: "ned@example.com",
            existing: nil
        )
        #expect(session.userIdentifier == "user-1")
        #expect(session.displayName == "Ned Adams")
        #expect(session.email == "ned@example.com")
    }

    @Test func reauthSameUserCarriesNameAndEmailForward() {
        // First auth captured the name/email; the re-auth credential omits them
        // (Apple's once-only release). Same user → carry them forward.
        let existing = AppleAuthSession(
            userIdentifier: "user-1",
            displayName: "Ned Adams",
            email: "ned@example.com"
        )
        let session = AppleCredentialResolver.resolve(
            userIdentifier: "user-1",
            credentialDisplayName: nil,
            credentialEmail: nil,
            existing: existing
        )
        #expect(session.displayName == "Ned Adams")
        #expect(session.email == "ned@example.com")
    }

    @Test func reauthDifferentUserDoesNotInheritPriorIdentity() {
        // A DIFFERENT Apple ID signing in (e.g. second person on a shared
        // device) must never inherit the previous user's name/email.
        let existing = AppleAuthSession(
            userIdentifier: "user-1",
            displayName: "Ned Adams",
            email: "ned@example.com"
        )
        let session = AppleCredentialResolver.resolve(
            userIdentifier: "user-2",
            credentialDisplayName: nil,
            credentialEmail: nil,
            existing: existing
        )
        #expect(session.userIdentifier == "user-2")
        #expect(session.displayName == nil)
        #expect(session.email == nil)
    }

    @Test func freshCredentialValuesOverrideExisting() {
        // A user who re-enabled name/email sharing gets the fresh values, not
        // the stale stored ones.
        let existing = AppleAuthSession(
            userIdentifier: "user-1",
            displayName: "Old Name",
            email: "old@example.com"
        )
        let session = AppleCredentialResolver.resolve(
            userIdentifier: "user-1",
            credentialDisplayName: "New Name",
            credentialEmail: "new@example.com",
            existing: existing
        )
        #expect(session.displayName == "New Name")
        #expect(session.email == "new@example.com")
    }
}
