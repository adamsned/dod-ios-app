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

    @Test func signOutClearsTheSession() {
        let store = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", displayName: "Ned")
        )
        let vm = AccountViewModel(store: store)
        vm.signOut()
        #expect(vm.isSignedIn == false)
        #expect(vm.session == nil)
        #expect((try? store.load()) == nil)
    }

    @Test func deleteAccountClearsTheSession() {
        let store = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "u1", displayName: "Ned")
        )
        let vm = AccountViewModel(store: store)
        vm.deleteAccount()
        #expect(vm.isSignedIn == false)
        #expect((try? store.load()) == nil)
    }
}
