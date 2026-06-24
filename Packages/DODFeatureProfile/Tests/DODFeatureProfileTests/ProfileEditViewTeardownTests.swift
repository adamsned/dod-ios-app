import DODSupport
import Testing

@testable import DODFeatureProfile

/// DUT-217 / DUT-296 / DUT-298 / DUT-268: ProfileEditView's Sign Out / Delete
/// Profile must clear ALL on-device identity rows (UserProfile, AppleAuthSession,
/// AND the GuestIdentity comment/rating row), revoke the Apple refresh token on
/// Delete (App Store 5.1.1(v)), run the Google-SDK teardown hook, and do each
/// step independently so one failure can't skip the others. These pin the pure
/// teardown both buttons drive.
@MainActor
@Suite("ProfileEditView teardown (DUT-217/268/296/298)") struct ProfileEditViewTeardownTests {

    @Test func deleteClearsAllRowsRevokesTheTokenAndDisconnectsGoogle() async throws {
        let profileStore = SpyProfileStore()
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", refreshToken: "rt-1")
        )
        let guest = SpyGuestIdentityStore()
        let revoker = SpyRevoker()
        let google = GoogleTeardownSpy()

        try await ProfileEditView.performAccountTeardown(
            revoke: true,
            profileStore: profileStore,
            sessionStore: sessionStore,
            guestIdentity: guest,
            revoker: revoker,
            googleTeardown: google.hook
        )

        #expect(profileStore.clearCalls == 1)
        #expect((try? sessionStore.load()) == nil)
        #expect(guest.clearCalls == 1)  // DUT-298 — guest identity row cleared
        #expect(revoker.revokedTokens == ["rt-1"])  // 5.1.1(v)
        #expect(google.revokeCalls == [true])  // DUT-296 — Google disconnect (revoke)
    }

    @Test func signOutClearsAllRowsButDoesNotRevokeAndStillSignsOutGoogle() async throws {
        let profileStore = SpyProfileStore()
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", refreshToken: "rt-1")
        )
        let guest = SpyGuestIdentityStore()
        let revoker = SpyRevoker()
        let google = GoogleTeardownSpy()

        try await ProfileEditView.performAccountTeardown(
            revoke: false,
            profileStore: profileStore,
            sessionStore: sessionStore,
            guestIdentity: guest,
            revoker: revoker,
            googleTeardown: google.hook
        )

        #expect(profileStore.clearCalls == 1)
        #expect((try? sessionStore.load()) == nil)
        #expect(guest.clearCalls == 1)  // DUT-298
        #expect(revoker.revokedTokens.isEmpty)  // Sign Out never revokes Apple
        #expect(google.revokeCalls == [false])  // DUT-296 — Google signOut (no revoke)
    }

    /// DUT-268 — a profile-clear failure must NOT skip the session/guest clears,
    /// the revoke, or the Google teardown; they all run, then the error surfaces.
    @Test func profileClearFailureStillRunsTheRestThenThrows() async {
        let profileStore = SpyProfileStore()
        profileStore.failClear = true
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", refreshToken: "rt-1")
        )
        let guest = SpyGuestIdentityStore()
        let revoker = SpyRevoker()
        let google = GoogleTeardownSpy()

        await #expect(throws: (any Error).self) {
            try await ProfileEditView.performAccountTeardown(
                revoke: true,
                profileStore: profileStore,
                sessionStore: sessionStore,
                guestIdentity: guest,
                revoker: revoker,
                googleTeardown: google.hook
            )
        }

        #expect((try? sessionStore.load()) == nil)  // ran despite the profile failure
        #expect(guest.clearCalls == 1)
        #expect(revoker.revokedTokens == ["rt-1"])
        #expect(google.revokeCalls == [true])
    }
}

private struct TeardownTestError: Error {}

private final class SpyProfileStore: ProfileStoring, @unchecked Sendable {
    private(set) var clearCalls = 0
    var failClear = false
    func load() async -> UserProfile? { nil }
    func save(_ profile: UserProfile) async throws {}
    func clear() async throws {
        clearCalls += 1
        if failClear { throw TeardownTestError() }
    }
    var hasProfile: Bool { get async { false } }
}

private final class SpyGuestIdentityStore: GuestIdentityStoring, @unchecked Sendable {
    private(set) var clearCalls = 0
    func load() throws -> GuestIdentity? { nil }
    func save(_ identity: GuestIdentity) throws {}
    func clear() throws { clearCalls += 1 }
}

private final class SpyRevoker: SiwaRevoking, @unchecked Sendable {
    private(set) var revokedTokens: [String] = []
    func exchange(authorizationCode: String) async throws -> String { "rt" }
    func revoke(refreshToken: String) async throws { revokedTokens.append(refreshToken) }
}

private final class GoogleTeardownSpy: @unchecked Sendable {
    private(set) var revokeCalls: [Bool] = []
    var hook: (@Sendable (Bool) async -> Void) {
        { revoke in self.revokeCalls.append(revoke) }
    }
}
