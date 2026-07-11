import DODSupport
import Foundation
import Security
import Testing

@testable import DODFeatureProfile

/// L1 for ``AppleProfileSignIn`` (DUT-189) — the profile-surface Sign in with
/// Apple handler that both persists the ``AppleAuthSession`` AND writes the local
/// ``UserProfile``. Since DUT-238 this is the app's single sign-in path (the
/// separate Settings ▸ Account handler was removed). In-memory stores, `nil`
/// revoker (no network).
struct AppleProfileSignInTests {

    @Test func firstSignIn_writesSessionAndProfile() async {
        let sessionStore = InMemoryAppleAuthSessionStore()
        let profileStore = InMemoryProfileStore()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: nil
        )

        let outcome = await signIn.apply(
            userIdentifier: "u1",
            displayName: "Ned Adams",
            email: "ned@example.com",
            authorizationCode: nil
        )

        // The session is persisted (the user is signed in).
        let session = try? sessionStore.load()
        #expect(session?.userIdentifier == "u1")
        #expect(session?.displayName == "Ned Adams")
        #expect(session?.email == "ned@example.com")

        // The local profile is filled from the credential — the new half.
        let profile = await profileStore.load()
        #expect(profile?.displayName == "Ned Adams")
        #expect(profile?.email == "ned@example.com")

        // The outcome tells the host a valid profile was written → it can dismiss.
        #expect(outcome.profileSaved == true)
        #expect(outcome.displayName == "Ned Adams")
        #expect(outcome.email == "ned@example.com")
    }

    @Test func withheldFields_persistSessionButNotProfile() async {
        let sessionStore = InMemoryAppleAuthSessionStore()
        let profileStore = InMemoryProfileStore()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: nil
        )

        // Apple withholds name + email (declined, or a re-auth with nothing on
        // file). The button still signs them in.
        let outcome = await signIn.apply(
            userIdentifier: "u2",
            displayName: nil,
            email: nil,
            authorizationCode: nil
        )

        #expect((try? sessionStore.load())?.userIdentifier == "u2")
        // No valid profile could be written, so the host keeps the editor open
        // for manual completion.
        let profile = await profileStore.load()
        #expect(profile == nil)
        #expect(outcome.profileSaved == false)
        // DUT-891b — the KEY regression: a re-auth / second-device sign-in where
        // Apple withheld the name/email is a genuine SUCCESS (a session was
        // persisted), NOT the "Couldn't Save Your Profile" write failure. The host
        // keys its error off `profileWriteFailed`, which must stay `false` here.
        #expect(outcome.signedIn == true)
        #expect(outcome.profileWriteFailed == false)
    }

    @Test func reSignIn_carriesFirstAuthNameForwardIntoProfile() async {
        // The first authorization seeded the session's name/email; a later
        // credential omits them (Apple only releases them once). The resolver
        // carries them forward for the same user, so the profile still fills.
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(
                userIdentifier: "u3",
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
            userIdentifier: "u3",
            displayName: nil,
            email: nil,
            authorizationCode: nil
        )

        let profile = await profileStore.load()
        #expect(profile?.displayName == "Chef Ned")
        #expect(profile?.email == "chef@dod.com")
        #expect(outcome.profileSaved == true)
    }

    @Test func signIn_preservesExistingProfileIdAndPhoto() async {
        // A returning user already has a profile (id + photo). Signing in must
        // merge the credential's name/email WITHOUT minting a new id or dropping
        // the photo (so saved-content attribution + the avatar survive).
        let existingID = UUID()
        let profileStore = InMemoryProfileStore(
            initial: UserProfile(
                id: existingID,
                displayName: "Old Name",
                email: "old@dod.com",
                photoFilename: "avatar.jpg"
            )
        )
        let sessionStore = InMemoryAppleAuthSessionStore()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: nil
        )

        _ = await signIn.apply(
            userIdentifier: "u4",
            displayName: "New Name",
            email: "new@dod.com",
            authorizationCode: nil
        )

        let profile = await profileStore.load()
        #expect(profile?.id == existingID)
        #expect(profile?.displayName == "New Name")
        #expect(profile?.email == "new@dod.com")
        #expect(profile?.photoFilename == "avatar.jpg")
    }

    /// DUT-503 — an Apple sign-in that overwrites a DIFFERENT user's session
    /// revokes that orphaned refresh token instead of dropping it from the
    /// Keychain, and does so BEFORE the new session is saved. Mirrors the Google
    /// path (DUT-279) so the two sign-in surfaces close the 5.1.1(v) gap alike.
    @Test func differentUserSignIn_revokesOverwrittenOrphanedToken() async {
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "user-a", refreshToken: "rt-a")
        )
        let profileStore = InMemoryProfileStore()
        let revoker = SpyRevoker(sessionStore: sessionStore)
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: revoker
        )

        _ = await signIn.apply(
            userIdentifier: "user-b",
            displayName: "Ned",
            email: "ned@example.com",
            authorizationCode: nil
        )

        // User A's orphaned token was revoked, exactly once.
        #expect(revoker.revokedTokens == ["rt-a"])
        // ...and the revoke happened BEFORE the new session was persisted.
        #expect(revoker.userIdentifierAtRevoke == "user-a")
        // The session is now User B's.
        #expect((try? sessionStore.load())?.userIdentifier == "user-b")
    }

    /// A same-user re-auth carries the token forward — it must NOT revoke.
    @Test func sameUserReAuth_doesNotRevoke() async {
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "user-a", refreshToken: "rt-a")
        )
        let profileStore = InMemoryProfileStore()
        let revoker = SpyRevoker(sessionStore: sessionStore)
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: revoker
        )

        _ = await signIn.apply(
            userIdentifier: "user-a",
            displayName: nil,
            email: nil,
            authorizationCode: nil
        )

        #expect(revoker.revokedTokens.isEmpty)
        #expect((try? sessionStore.load())?.refreshToken == "rt-a")  // carried forward
    }

    /// DUT-506 — an EMPTY `userIdentifier` is not a valid sign-in: no session is
    /// persisted (so `hasSession` stays false), no profile is written, and the
    /// outcome reports nothing saved. Mirrors the Google side (DUT-285), which
    /// drops an empty id before any session is created.
    @Test func emptyUserIdentifier_persistsNothing() async {
        let sessionStore = InMemoryAppleAuthSessionStore()
        let profileStore = InMemoryProfileStore()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: nil
        )

        let outcome = await signIn.apply(
            userIdentifier: "",
            displayName: "Ned Adams",
            email: "ned@example.com",
            authorizationCode: nil
        )

        #expect((try? sessionStore.load()) == nil)  // no phantom `""` session
        #expect(await profileStore.load() == nil)
        #expect(outcome.profileSaved == false)
        #expect(outcome.displayName == nil)
        #expect(outcome.email == nil)
    }

    /// DUT-506 — a WHITESPACE-only id is just as invalid (it trims to empty), and
    /// is rejected on the same no-op path.
    @Test func whitespaceUserIdentifier_persistsNothing() async {
        let sessionStore = InMemoryAppleAuthSessionStore()
        let profileStore = InMemoryProfileStore()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: nil
        )

        let outcome = await signIn.apply(
            userIdentifier: "  \n\t ",
            displayName: "Ned Adams",
            email: "ned@example.com",
            authorizationCode: nil
        )

        #expect((try? sessionStore.load()) == nil)
        #expect(await profileStore.load() == nil)
        #expect(outcome.profileSaved == false)
    }

    /// DUT-506 composes with DUT-503: an empty-id sign-in is rejected BEFORE any
    /// revoke runs, so a different user's on-file token is left untouched (an empty
    /// id is a non-event, not a "different user" that would trigger a revoke).
    @Test func emptyUserIdentifier_doesNotRevokeExistingToken() async {
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "user-a", refreshToken: "rt-a")
        )
        let profileStore = InMemoryProfileStore()
        let revoker = SpyRevoker(sessionStore: sessionStore)
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: revoker
        )

        _ = await signIn.apply(
            userIdentifier: "",
            displayName: nil,
            email: nil,
            authorizationCode: nil
        )

        // No revoke fired, and User A's session is left intact.
        #expect(revoker.revokedTokens.isEmpty)
        #expect((try? sessionStore.load())?.userIdentifier == "user-a")
    }

    /// DUT-472 / DUT-503 — a revoke FAILURE must not block the new sign-in: the
    /// different user's session is still persisted (best-effort revoke, same error
    /// posture as the Google path).
    @Test func revokeFailure_stillCompletesSignIn() async {
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "user-a", refreshToken: "rt-a")
        )
        let profileStore = InMemoryProfileStore()
        let revoker = FailingRevoker()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: revoker
        )

        let outcome = await signIn.apply(
            userIdentifier: "user-b",
            displayName: "Ned",
            email: "ned@example.com",
            authorizationCode: nil
        )

        // The revoke was attempted (best-effort) but threw...
        #expect(revoker.revokeAttempted)
        // ...and the new sign-in still completed: User B's session + profile persist.
        #expect((try? sessionStore.load())?.userIdentifier == "user-b")
        #expect(outcome.profileSaved == true)
    }

    /// DUT-928 — a Keychain WRITE failure at sign-in must NOT masquerade as
    /// success. Before this fix `apply` did `try? sessionStore.save(...)` and
    /// still returned `signedIn: true`, so a signed-device write failure left the
    /// user believing they were logged in while nothing persisted (the iPad
    /// "signs in but doesn't stick" bug). The outcome now reports
    /// `signedIn == false` + `sessionSaveFailed == true` (carrying the raw
    /// OSStatus) so the host surfaces a real error, and no profile is written
    /// when the session itself didn't persist.
    @Test func sessionSaveFailure_reportsNotSignedIn() async {
        let sessionStore = ThrowingSessionStore(status: errSecMissingEntitlement)
        let profileStore = InMemoryProfileStore()
        let signIn = AppleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: nil
        )

        let outcome = await signIn.apply(
            userIdentifier: "u1",
            displayName: "Ned Adams",
            email: "ned@example.com",
            authorizationCode: nil
        )

        #expect(outcome.signedIn == false)
        #expect(outcome.sessionSaveFailed == true)
        #expect(outcome.sessionSaveStatus == errSecMissingEntitlement)
        // The early return happens before the profile write, so nothing is saved.
        #expect(await profileStore.load() == nil)
        #expect(outcome.profileSaved == false)
    }
}

/// A session store whose `save` always throws a Keychain error, to prove a
/// device-side write failure surfaces as a NOT-signed-in outcome (DUT-928)
/// rather than the former silent `try?`-swallowed success.
private final class ThrowingSessionStore: AppleAuthSessionStoring, @unchecked Sendable {
    private let status: OSStatus
    init(status: OSStatus) { self.status = status }
    func load() throws -> AppleAuthSession? { nil }
    func save(_ session: AppleAuthSession) throws { throw AppleAuthError.keychainFailed(status) }
    func clear() throws {}
}

/// A revoker whose `revoke` always throws, to prove a revoke failure doesn't block
/// the overwriting sign-in (best-effort revoke posture).
private final class FailingRevoker: SiwaRevoking, @unchecked Sendable {
    private(set) var revokeAttempted = false
    private struct RevokeFailed: Error {}

    func exchange(authorizationCode: String) async throws -> String { "rt" }

    func revoke(refreshToken: String) async throws {
        revokeAttempted = true
        throw RevokeFailed()
    }
}

/// Records revoked tokens and captures the on-file session's user at revoke time,
/// so a test can assert the revoke ran BEFORE the overwriting session was saved.
private final class SpyRevoker: SiwaRevoking, @unchecked Sendable {
    private let sessionStore: any AppleAuthSessionStoring
    private(set) var revokedTokens: [String] = []
    private(set) var userIdentifierAtRevoke: String?

    init(sessionStore: any AppleAuthSessionStoring) {
        self.sessionStore = sessionStore
    }

    func exchange(authorizationCode: String) async throws -> String { "rt" }

    func revoke(refreshToken: String) async throws {
        userIdentifierAtRevoke = (try? sessionStore.load())?.userIdentifier
        revokedTokens.append(refreshToken)
    }
}
