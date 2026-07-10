import DODSupport
import Foundation
import Testing

@testable import DODFeatureProfile

/// DUT-891b regression L1 for the ``AppleProfileSignIn/Outcome`` `signedIn` +
/// `profileWriteFailed` signals — the fields the host keys its error/dismiss
/// decision off of. The bug: a re-auth (or a second device) where Apple withheld
/// the name/email came back `profileSaved == false`, which the editor treated as
/// the "Couldn't Save Your Profile" failure even though the user WAS signed in.
/// These pin the three distinct results apart so a plain "nothing to write" can
/// never again read as a failure.
struct AppleProfileSignInOutcomeTests {

    /// The KEY regression: the credential carried BOTH a name and an email but the
    /// store's `save` threw (the real "Couldn't Save Your Profile" write failure —
    /// e.g. a missing keychain entitlement). This is the ONLY situation that sets
    /// `profileWriteFailed`; the session still persists (the user is signed in).
    @Test func writeFailure_flagsProfileWriteFailedButStillSignsIn() async {
        let sessionStore = InMemoryAppleAuthSessionStore()
        let profileStore = FailingProfileStore()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: nil
        )

        let outcome = await signIn.apply(
            userIdentifier: "u-write-fail",
            displayName: "Ned Adams",
            email: "ned@example.com",
            authorizationCode: nil
        )

        // The session still persisted (the user IS signed in)...
        #expect((try? sessionStore.load())?.userIdentifier == "u-write-fail")
        #expect(outcome.signedIn == true)
        // ...but the profile write failed, so the host should surface the error.
        #expect(outcome.profileSaved == false)
        #expect(outcome.profileWriteFailed == true)
    }

    /// A re-auth / second-device sign-in where Apple withheld the name/email, with
    /// nothing on file to carry forward. `profileSaved == false` — but this is a
    /// SUCCESS (a session persisted), NOT a write failure. The host must keep the
    /// editor open for manual entry, never show "Couldn't Save Your Profile".
    @Test func withheldFields_areSignedInWithoutWriteFailure() async {
        let sessionStore = InMemoryAppleAuthSessionStore()
        let profileStore = InMemoryProfileStore()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: nil
        )

        let outcome = await signIn.apply(
            userIdentifier: "u-reauth",
            displayName: nil,
            email: nil,
            authorizationCode: nil
        )

        #expect(outcome.signedIn == true)
        #expect(outcome.profileSaved == false)
        #expect(outcome.profileWriteFailed == false)
    }

    /// The DUT-506 blank-id early return persists no session, so it is a non-event
    /// (`signedIn == false`), NOT a write failure — the host stays silent.
    @Test func blankIdentifier_reportsNotSignedInAndNoWriteFailure() async {
        let sessionStore = InMemoryAppleAuthSessionStore()
        let profileStore = InMemoryProfileStore()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: nil
        )

        let outcome = await signIn.apply(
            userIdentifier: "",
            displayName: nil,
            email: nil,
            authorizationCode: nil
        )

        #expect(outcome.signedIn == false)
        #expect(outcome.profileSaved == false)
        #expect(outcome.profileWriteFailed == false)
    }

    /// A same-user re-auth that carries a stored name/email forward writes a full
    /// profile, so it is an unambiguous success: signed in, profile saved, and NOT
    /// flagged a write failure.
    @Test func reAuthCarryingNameForward_isCleanSuccess() async {
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(
                userIdentifier: "u-return",
                displayName: "Chef Ned",
                email: "chef@dod.com"
            )
        )
        let profileStore = InMemoryProfileStore()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: nil
        )

        let outcome = await signIn.apply(
            userIdentifier: "u-return",
            displayName: nil,
            email: nil,
            authorizationCode: nil
        )

        #expect(outcome.signedIn == true)
        #expect(outcome.profileSaved == true)
        #expect(outcome.profileWriteFailed == false)
        #expect(outcome.displayName == "Chef Ned")
    }
}

/// A profile store whose `save` always throws, standing in for the real
/// "Couldn't Save Your Profile" write failure (e.g. a missing keychain
/// entitlement) so the `profileWriteFailed` flag can be exercised.
private actor FailingProfileStore: ProfileStoring {
    private struct SaveFailed: Error {}

    func load() async -> UserProfile? { nil }
    func save(_ profile: UserProfile) async throws { throw SaveFailed() }
    func clear() async throws {}
    var hasProfile: Bool { false }
}
