import Testing

@testable import DODFeatureProfile

/// Sign in with Google scaffold — the seam is L1-testable without the SDK.
@Suite("Google sign-in scaffold")
struct GoogleProfileSignInTests {

    @Test func configIsNotConfiguredUntilAClientIDIsWired() {
        #expect(GoogleSignInConfig.clientID.isEmpty)
        #expect(GoogleSignInConfig.isConfigured == false)
    }

    @Test func unconfiguredProviderReturnsNotConfigured() async {
        let result = await UnconfiguredGoogleSignInProvider().signIn()
        #expect(result == .notConfigured)
    }
}
