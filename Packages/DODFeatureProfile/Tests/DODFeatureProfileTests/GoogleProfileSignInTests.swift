import DODSupport
import Security
import Testing

@testable import DODFeatureProfile

/// Sign in with Google (DUT-276) — the seam + persist are L1-testable without the SDK.
@Suite("Google sign-in")
struct GoogleProfileSignInTests {

    @Test func configIsWiredWithARealClientID() {
        #expect(GoogleSignInConfig.clientID.hasSuffix(".apps.googleusercontent.com"))
        #expect(GoogleSignInConfig.isConfigured)
    }

    @Test func unconfiguredProviderReturnsNotConfigured() async {
        let result = await UnconfiguredGoogleSignInProvider().signIn()
        #expect(result == .notConfigured)
    }

    /// DUT-279 — a Google sign-in that overwrites a DIFFERENT user's Apple
    /// session revokes that orphaned Apple refresh token instead of dropping it.
    @Test func googleSignInRevokesAnOverwrittenDifferentUserAppleToken() async {
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "apple-user", refreshToken: "rt-apple")
        )
        let revoker = SpyRevoker()
        let signIn = GoogleProfileSignIn(
            profileStore: NoopProfileStore(),
            sessionStore: sessionStore,
            revoker: revoker
        )
        _ = await signIn.apply(userIdentifier: "google-123", displayName: "Ned", email: "n@x.com")
        #expect(revoker.revokedTokens == ["rt-apple"])  // orphaned Apple token revoked
        #expect((try? sessionStore.load())?.userIdentifier == "google-123")  // overwritten
    }

    /// Same-user re-auth carries the token forward (no revoke).
    @Test func googleSignInForSameUserCarriesTheTokenForward() async {
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", refreshToken: "rt-1")
        )
        let revoker = SpyRevoker()
        let signIn = GoogleProfileSignIn(
            profileStore: NoopProfileStore(),
            sessionStore: sessionStore,
            revoker: revoker
        )
        _ = await signIn.apply(userIdentifier: "u1", displayName: nil, email: nil)
        #expect(revoker.revokedTokens.isEmpty)
        #expect((try? sessionStore.load())?.refreshToken == "rt-1")  // carried forward
    }

    /// DUT-701 — a Google sign-in must persist the session tagged `.google` so the
    /// Apple credential-revocation validator skips it (the other half of the fix:
    /// see `AppleCredentialValidatorTests.googleProviderSessionIsNeverPolledOrCleared`).
    @Test func googleSignInTagsSessionAsGoogleProvider() async {
        let sessionStore = InMemoryAppleAuthSessionStore()
        let signIn = GoogleProfileSignIn(
            profileStore: NoopProfileStore(),
            sessionStore: sessionStore,
            revoker: SpyRevoker()
        )
        _ = await signIn.apply(userIdentifier: "google-123", displayName: "Ned", email: "n@x.com")
        #expect((try? sessionStore.load())?.provider == .google)
    }

    /// (this bug) — the Google mirror of `AppleProfileSignInTests
    /// .sessionSaveFailure_reportsNotSignedIn` (DUT-928). Before this fix, `apply`
    /// did `try? sessionStore.save(googleSession)` and still returned
    /// `signedIn: true`, so a signed-device Keychain write failure left the user
    /// believing they were logged in via Google while nothing persisted — the
    /// same "signs in but doesn't stick" bug DUT-928 already closed for Apple.
    /// The outcome must now report `signedIn == false` + `sessionSaveFailed ==
    /// true` (carrying the raw OSStatus), with no profile written.
    @Test func sessionSaveFailure_reportsNotSignedIn() async {
        let sessionStore = ThrowingGoogleSessionStore(status: errSecMissingEntitlement)
        let profileStore = NoopRecordingProfileStore()
        let signIn = GoogleProfileSignIn(
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: SpyRevoker()
        )

        let outcome = await signIn.apply(
            userIdentifier: "google-123",
            displayName: "Ned Adams",
            email: "ned@example.com"
        )

        #expect(outcome.signedIn == false)
        #expect(outcome.sessionSaveFailed == true)
        #expect(outcome.sessionSaveStatus == errSecMissingEntitlement)
        // The early return happens before the profile write, so nothing is saved.
        #expect(profileStore.saveCallCount == 0)
        #expect(outcome.profileSaved == false)
    }
}

private final class NoopProfileStore: ProfileStoring, @unchecked Sendable {
    func load() async -> UserProfile? { nil }
    func save(_ profile: UserProfile) async throws {}
    func clear() async throws {}
    var hasProfile: Bool { get async { false } }
}

/// Like `NoopProfileStore`, but records whether `save` was ever called, so a
/// test can prove a failed session save short-circuits BEFORE the profile
/// write is attempted.
private final class NoopRecordingProfileStore: ProfileStoring, @unchecked Sendable {
    private(set) var saveCallCount = 0
    func load() async -> UserProfile? { nil }
    func save(_ profile: UserProfile) async throws { saveCallCount += 1 }
    func clear() async throws {}
    var hasProfile: Bool { get async { false } }
}

private final class SpyRevoker: SiwaRevoking, @unchecked Sendable {
    private(set) var revokedTokens: [String] = []
    func exchange(authorizationCode: String) async throws -> String { "rt" }
    func revoke(refreshToken: String) async throws { revokedTokens.append(refreshToken) }
}

/// A session store whose `save` always throws a Keychain error, to prove a
/// device-side write failure surfaces as a NOT-signed-in outcome (this bug's
/// Google-side mirror of DUT-928) rather than a silent `try?`-swallowed success.
private final class ThrowingGoogleSessionStore: AppleAuthSessionStoring, @unchecked Sendable {
    private let status: OSStatus
    init(status: OSStatus) { self.status = status }
    func load() throws -> AppleAuthSession? { nil }
    func save(_ session: AppleAuthSession) throws { throw AppleAuthError.keychainFailed(status) }
    func clear() throws {}
}
