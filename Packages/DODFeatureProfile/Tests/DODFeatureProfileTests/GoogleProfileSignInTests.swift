import DODSupport
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
}

private final class NoopProfileStore: ProfileStoring, @unchecked Sendable {
    func load() async -> UserProfile? { nil }
    func save(_ profile: UserProfile) async throws {}
    func clear() async throws {}
    var hasProfile: Bool { get async { false } }
}

private final class SpyRevoker: SiwaRevoking, @unchecked Sendable {
    private(set) var revokedTokens: [String] = []
    func exchange(authorizationCode: String) async throws -> String { "rt" }
    func revoke(refreshToken: String) async throws { revokedTokens.append(refreshToken) }
}
