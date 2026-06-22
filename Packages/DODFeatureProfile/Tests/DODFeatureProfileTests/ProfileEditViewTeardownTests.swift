import DODSupport
import Testing

@testable import DODFeatureProfile

/// DUT-217: ProfileEditView's Sign Out / Delete Profile must clear BOTH coupled
/// Keychain rows (the UserProfile AND the AppleAuthSession), and **Delete must
/// revoke** the Apple refresh token (App Store 5.1.1(v)). Before the fix the
/// editor only cleared the profile, leaving a live, un-revoked token on the
/// primary sign-in surface (DUT-189). These pin the pure teardown both buttons
/// drive.
@MainActor
@Suite("ProfileEditView teardown (DUT-217)") struct ProfileEditViewTeardownTests {

    @Test func deleteClearsBothRowsAndRevokesTheToken() async throws {
        let profileStore = SpyProfileStore()
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", refreshToken: "rt-1")
        )
        let revoker = SpyRevoker()

        try await ProfileEditView.performAccountTeardown(
            revoke: true,
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: revoker
        )

        #expect(profileStore.clearCalls == 1)  // profile row cleared
        #expect((try? sessionStore.load()) == nil)  // session row cleared
        #expect(revoker.revokedTokens == ["rt-1"])  // token revoked (5.1.1(v))
    }

    @Test func signOutClearsBothRowsButDoesNotRevoke() async throws {
        let profileStore = SpyProfileStore()
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", refreshToken: "rt-1")
        )
        let revoker = SpyRevoker()

        try await ProfileEditView.performAccountTeardown(
            revoke: false,
            profileStore: profileStore,
            sessionStore: sessionStore,
            revoker: revoker
        )

        #expect(profileStore.clearCalls == 1)
        #expect((try? sessionStore.load()) == nil)
        #expect(revoker.revokedTokens.isEmpty)  // Sign Out never revokes
    }
}

private final class SpyProfileStore: ProfileStoring, @unchecked Sendable {
    private(set) var clearCalls = 0
    func load() async -> UserProfile? { nil }
    func save(_ profile: UserProfile) async throws {}
    func clear() async throws { clearCalls += 1 }
    var hasProfile: Bool { get async { false } }
}

private final class SpyRevoker: SiwaRevoking, @unchecked Sendable {
    private(set) var revokedTokens: [String] = []
    func exchange(authorizationCode: String) async throws -> String { "rt" }
    func revoke(refreshToken: String) async throws { revokedTokens.append(refreshToken) }
}
