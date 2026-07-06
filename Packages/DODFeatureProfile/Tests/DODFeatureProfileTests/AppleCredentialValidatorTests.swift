import DODSupport
import Foundation
import Testing

@testable import DODFeatureProfile

/// DUT-635 — L1 for ``AppleCredentialValidator``: a revoked / expired / not-found
/// Apple credential must clear the local session so the user isn't stranded
/// signed-in forever, while an authorized (or inconclusive) credential leaves
/// the session untouched. The platform credential-state lookup is injected as a
/// closure, so the whole reaction is testable without `AuthenticationServices`.
@Suite("AppleCredentialValidator (DUT-635)")
struct AppleCredentialValidatorTests {

    /// Bundles the validator with the stores it was built over so tests can
    /// assert side effects. (A struct, not a tuple — SwiftLint caps tuples at 2.)
    private struct Fixture {
        let validator: AppleCredentialValidator
        let sessionStore: InMemoryAppleAuthSessionStore
        let profileStore: InMemoryProfileStore
        let guest: SpyGuest
    }

    private func makeFixture(
        session: AppleAuthSession?,
        status: AppleCredentialValidator.Status?,
        onCleared: (@Sendable () async -> Void)? = nil
    ) -> Fixture {
        let sessionStore =
            session.map { InMemoryAppleAuthSessionStore(initial: $0) }
            ?? InMemoryAppleAuthSessionStore()
        let profileStore = InMemoryProfileStore(
            initial: UserProfile(id: UUID(), displayName: "Ned", email: "ned@dod.com")
        )
        let guest = SpyGuest()
        let validator = AppleCredentialValidator(
            sessionStore: sessionStore,
            profileStore: profileStore,
            revoker: nil,
            guestIdentity: guest,
            onSessionCleared: onCleared,
            credentialStatus: { _ in status }
        )
        return Fixture(
            validator: validator,
            sessionStore: sessionStore,
            profileStore: profileStore,
            guest: guest
        )
    }

    @Test func revokedCredentialClearsSession() async {
        let cleared = Flag()
        let fixture = makeFixture(
            session: AppleAuthSession(userIdentifier: "u1", refreshToken: "rt"),
            status: .revoked,
            onCleared: { cleared.set() }
        )

        let didClear = await fixture.validator.validateOnLaunchOrForeground()

        #expect(didClear)
        #expect((try? fixture.sessionStore.load()) == nil)
        #expect(await fixture.profileStore.load() == nil)
        #expect(fixture.guest.clearCalls == 1)  // guest identity row cleared too
        #expect(cleared.value)
    }

    @Test func notFoundCredentialClearsSession() async {
        let fixture = makeFixture(
            session: AppleAuthSession(userIdentifier: "u1"),
            status: .notFound
        )

        #expect(await fixture.validator.validateOnLaunchOrForeground())
        #expect((try? fixture.sessionStore.load()) == nil)
    }

    @Test func authorizedCredentialKeepsSession() async {
        let fixture = makeFixture(
            session: AppleAuthSession(userIdentifier: "u1"),
            status: .authorized
        )

        let didClear = await fixture.validator.validateOnLaunchOrForeground()

        #expect(!didClear)
        #expect((try? fixture.sessionStore.load())?.userIdentifier == "u1")
        #expect(await fixture.profileStore.load() != nil)
    }

    @Test func inconclusiveLookupKeepsSession() async {
        // Offline / transient failure surfaces as a nil status — never sign the
        // user out on an ambiguous signal.
        let fixture = makeFixture(
            session: AppleAuthSession(userIdentifier: "u1"),
            status: nil
        )

        #expect(await fixture.validator.validateOnLaunchOrForeground() == false)
        #expect((try? fixture.sessionStore.load())?.userIdentifier == "u1")
    }

    @Test func noSessionIsANoOp() async {
        let lookupRan = Flag()
        let sessionStore = InMemoryAppleAuthSessionStore()
        let validator = AppleCredentialValidator(
            sessionStore: sessionStore,
            profileStore: InMemoryProfileStore(),
            revoker: nil,
            guestIdentity: SpyGuest(),
            credentialStatus: { _ in
                lookupRan.set()
                return .revoked
            }
        )

        #expect(await validator.validateOnLaunchOrForeground() == false)
        #expect(!lookupRan.value)  // no session → never even hit the platform lookup
    }

    @Test func handleCredentialRevokedClearsSession() async {
        // The live-notification path clears without re-polling.
        let fixture = makeFixture(
            session: AppleAuthSession(userIdentifier: "u1", refreshToken: "rt"),
            status: .authorized  // status is irrelevant on the notification path
        )

        await fixture.validator.handleCredentialRevoked()

        #expect((try? fixture.sessionStore.load()) == nil)
        #expect(await fixture.profileStore.load() == nil)
        #expect(fixture.guest.clearCalls == 1)
    }

    @Test func handleCredentialRevokedWithNoSessionIsANoOp() async {
        let guest = SpyGuest()
        let validator = AppleCredentialValidator(
            sessionStore: InMemoryAppleAuthSessionStore(),
            profileStore: InMemoryProfileStore(),
            revoker: nil,
            guestIdentity: guest,
            credentialStatus: { _ in .authorized }
        )

        await validator.handleCredentialRevoked()
        #expect(guest.clearCalls == 0)  // nothing to tear down
    }
}

/// Records `clear()` calls so a test can assert the guest-identity row was torn
/// down alongside the session/profile.
private final class SpyGuest: GuestIdentityStoring, @unchecked Sendable {
    private(set) var clearCalls = 0
    func load() throws -> GuestIdentity? { nil }
    func save(_ identity: GuestIdentity) throws {}
    func clear() throws { clearCalls += 1 }
}

/// Sendable boolean flag for asserting a `@Sendable` closure ran / fired.
private final class Flag: @unchecked Sendable {
    private(set) var value = false
    func set() { value = true }
}
