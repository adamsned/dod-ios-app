import DODFeatureProfile
import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 coverage for ``AccountViewModel`` (US-46 / AC-46.2..46.4) — the
/// signed-in/out state machine over an injected ``AppleAuthSessionStoring``,
/// including the first-auth merge (delegated to `AppleCredentialResolver`),
/// Sign Out, and Delete Account. Driven through an
/// ``InMemoryAppleAuthSessionStore`` so no Keychain is touched.
@MainActor
@Suite("AccountViewModel (US-46)")
struct AccountViewModelTests {

    @Test func startsSignedOutWithEmptyStore() {
        let vm = AccountViewModel(store: InMemoryAppleAuthSessionStore())
        #expect(vm.isSignedIn == false)
        #expect(vm.session == nil)
    }

    @Test func seedsSignedInFromExistingSession() {
        let store = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", displayName: "Ned", email: "n@x.com")
        )
        let vm = AccountViewModel(store: store)
        #expect(vm.isSignedIn)
        #expect(vm.session?.displayName == "Ned")
    }

    @Test func firstAuthPersistsNameAndEmail() {
        let store = InMemoryAppleAuthSessionStore()
        let vm = AccountViewModel(store: store)
        vm.applySignIn(userIdentifier: "u1", displayName: "Ned Adams", email: "ned@example.com")
        #expect(vm.isSignedIn)
        #expect(vm.session?.userIdentifier == "u1")
        #expect(vm.session?.displayName == "Ned Adams")
        #expect(vm.session?.email == "ned@example.com")
        // Persisted, not just in memory on the VM.
        #expect((try? store.load())?.displayName == "Ned Adams")
    }

    @Test func reauthSameUserKeepsFirstAuthNameAndEmail() {
        let store = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", displayName: "Ned", email: "ned@x.com")
        )
        let vm = AccountViewModel(store: store)
        // Apple omits name/email on re-auth — must carry forward for the same user.
        vm.applySignIn(userIdentifier: "u1", displayName: nil, email: nil)
        #expect(vm.session?.displayName == "Ned")
        #expect(vm.session?.email == "ned@x.com")
    }

    @Test func differentUserDoesNotInheritPriorIdentity() {
        let store = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", displayName: "Ned", email: "ned@x.com")
        )
        let vm = AccountViewModel(store: store)
        vm.applySignIn(userIdentifier: "u2", displayName: nil, email: nil)
        #expect(vm.session?.userIdentifier == "u2")
        #expect(vm.session?.displayName == nil)
        #expect(vm.session?.email == nil)
    }

    @Test func signOutClearsBothSessionAndProfile() async {
        let store = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", displayName: "Ned")
        )
        let profileStore = SpyProfileStore()
        let vm = AccountViewModel(store: store, profileStore: profileStore)
        await vm.signOut()
        #expect(vm.isSignedIn == false)
        #expect(vm.session == nil)
        #expect((try? store.load()) == nil)
        // DUT-217: the coupled UserProfile row is cleared too.
        #expect(profileStore.clearCalls == 1)
    }

    @Test func deleteAccountClearsBothSessionAndProfile() async {
        let store = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", displayName: "Ned")
        )
        let profileStore = SpyProfileStore()
        let vm = AccountViewModel(store: store, profileStore: profileStore)
        await vm.deleteAccount()
        #expect(vm.isSignedIn == false)
        #expect((try? store.load()) == nil)
        // DUT-217: an account deletion must not leave personal data on-device.
        #expect(profileStore.clearCalls == 1)
    }

    // MARK: - AC-46.6 (DUT-98) — token exchange + revoke

    @Test func deleteAccountRevokesTheRefreshTokenViaTheWorker() async {
        let store = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", refreshToken: "rt-1")
        )
        let spy = SpyRevoker()
        let vm = AccountViewModel(store: store, profileStore: SpyProfileStore(), revoker: spy)
        await vm.deleteAccount()
        #expect(vm.session == nil)
        #expect(spy.revokedTokens == ["rt-1"])
    }

    @Test func signInExchangesTheCodeAndStoresTheRefreshToken() async {
        let store = InMemoryAppleAuthSessionStore()
        let spy = SpyRevoker()
        spy.exchangeReturn = "rt-new"
        let vm = AccountViewModel(store: store, revoker: spy)
        await confirmation { confirmed in
            spy.onExchange = { _ in confirmed() }
            vm.applySignIn(
                userIdentifier: "u1",
                displayName: "Ned",
                email: "n@x.com",
                authorizationCode: "code-1"
            )
            #expect(vm.session?.refreshToken == nil)  // immediate session; token pending
            try? await Task.sleep(for: .milliseconds(300))
        }
        #expect(spy.exchangedCodes == ["code-1"])
        #expect(vm.session?.refreshToken == "rt-new")
        #expect((try? store.load())?.refreshToken == "rt-new")
    }

    @Test func deleteWithoutRefreshTokenDoesNotCallRevoker() async {
        let store = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1")  // no refresh token
        )
        let spy = SpyRevoker()
        let vm = AccountViewModel(store: store, profileStore: SpyProfileStore(), revoker: spy)
        await vm.deleteAccount()
        #expect(vm.session == nil)
        #expect(spy.revokedTokens.isEmpty)
    }
}

/// Records `clear()` calls for the DUT-217 profile-teardown assertions.
/// `@unchecked Sendable` is sound: access is MainActor-driven, like ``SpyRevoker``.
private final class SpyProfileStore: ProfileStoring, @unchecked Sendable {
    private(set) var clearCalls = 0
    func load() async -> UserProfile? { nil }
    func save(_ profile: UserProfile) async throws {}
    func clear() async throws { clearCalls += 1 }
    var hasProfile: Bool { get async { false } }
}

/// Records exchange/revoke calls for the AccountViewModel async-path tests.
/// `@unchecked Sendable` is sound here: every call runs on the MainActor (the
/// view-model + its Tasks are MainActor-isolated, as is this @MainActor suite).
private final class SpyRevoker: SiwaRevoking, @unchecked Sendable {
    var exchangeReturn: String? = "rt-exchanged"
    private(set) var exchangedCodes: [String] = []
    private(set) var revokedTokens: [String] = []
    var onExchange: (@Sendable (String) -> Void)?
    var onRevoke: (@Sendable (String) -> Void)?

    func exchange(authorizationCode: String) async throws -> String {
        exchangedCodes.append(authorizationCode)
        onExchange?(authorizationCode)
        guard let token = exchangeReturn else { throw SiwaRevokeError.missingRefreshToken }
        return token
    }

    func revoke(refreshToken: String) async throws {
        revokedTokens.append(refreshToken)
        onRevoke?(refreshToken)
    }
}
