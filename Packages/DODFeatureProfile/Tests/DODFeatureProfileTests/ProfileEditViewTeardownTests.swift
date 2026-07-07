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

    /// DUT-565 — the injected `extraTeardown` seam (recent searches + comment
    /// moderation, wired by the App composition root) must run on BOTH Sign Out
    /// and Delete, mirroring the guest-identity "don't prefill for the NEXT user"
    /// treatment. Asserted via a spy on the closure.
    @Test func extraTeardownRunsOnBothSignOutAndDelete() async throws {
        let extras = ExtraTeardownSpy()

        try await ProfileEditView.performAccountTeardown(
            revoke: false,
            profileStore: SpyProfileStore(),
            sessionStore: InMemoryAppleAuthSessionStore(),
            guestIdentity: SpyGuestIdentityStore(),
            revoker: SpyRevoker(),
            extraTeardown: extras.hook
        )
        #expect(extras.calls == [false])  // Sign Out

        try await ProfileEditView.performAccountTeardown(
            revoke: true,
            profileStore: SpyProfileStore(),
            sessionStore: InMemoryAppleAuthSessionStore(),
            guestIdentity: SpyGuestIdentityStore(),
            revoker: SpyRevoker(),
            extraTeardown: extras.hook
        )
        #expect(extras.calls == [false, true])  // Delete also ran
    }

    /// DUT-678 — a FAILED revoke must not fail (or block) account deletion: the
    /// local rows are already cleared and the token expires server-side, so the
    /// teardown still completes without throwing. (The failure is surfaced via
    /// an error log — not asserted here, but the point is it's no longer a
    /// silent `try?` that also hid the throw from deletion completion.)
    @Test func failedRevokeStillCompletesDeletionWithoutThrowing() async throws {
        let profileStore = SpyProfileStore()
        let sessionStore = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", refreshToken: "rt-1")
        )
        let guest = SpyGuestIdentityStore()
        let failingRevoker = FailingRevoker()

        // Must NOT throw — deletion completes for the user despite the revoke
        // failing (App Store 5.1.1(v) revoke is best-effort at this layer).
        try await ProfileEditView.performAccountTeardown(
            revoke: true,
            profileStore: profileStore,
            sessionStore: sessionStore,
            guestIdentity: guest,
            revoker: failingRevoker
        )

        #expect(failingRevoker.attempts == 1)  // the revoke WAS attempted
        #expect(profileStore.clearCalls == 1)  // local teardown still ran
        #expect((try? sessionStore.load()) == nil)
        #expect(guest.clearCalls == 1)
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

/// DUT-678 — a revoker whose `revoke` always throws, to pin that a failed
/// revoke is surfaced (logged) but does NOT fail the user's account deletion.
private final class FailingRevoker: SiwaRevoking, @unchecked Sendable {
    private(set) var attempts = 0
    func exchange(authorizationCode: String) async throws -> String { "rt" }
    func revoke(refreshToken: String) async throws {
        attempts += 1
        throw SiwaRevokeError.http(504)
    }
}

private final class GoogleTeardownSpy: @unchecked Sendable {
    private(set) var revokeCalls: [Bool] = []
    var hook: (@Sendable (Bool) async -> Void) {
        { revoke in self.revokeCalls.append(revoke) }
    }
}

/// DUT-565 — spies on the injected `extraTeardown` (recent searches + comment
/// moderation clears wired by the App composition root).
@MainActor
private final class ExtraTeardownSpy {
    private(set) var calls: [Bool] = []
    var hook: (@MainActor (Bool) async -> Void) {
        { revoke in self.calls.append(revoke) }
    }
}
