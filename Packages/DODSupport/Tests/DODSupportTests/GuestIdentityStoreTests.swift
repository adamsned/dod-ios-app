import Testing

@testable import DODSupport

// MARK: - In-memory implementation (always runnable)

/// `InMemoryGuestIdentityStore` covers the protocol contract under unit
/// tests without touching the real Keychain. These run on every PR.
///
/// Spec trace: US-15 (guest identity).
@Suite("InMemoryGuestIdentityStore (US-15)")
struct InMemoryGuestIdentityStoreTests {

    @Test func roundTripSaveLoad() throws {
        let store = InMemoryGuestIdentityStore()
        let identity = GuestIdentity(displayName: "Nate", email: "nate@example.com")
        try store.save(identity)
        let loaded = try store.load()
        #expect(loaded == identity)
    }

    @Test func loadReturnsNilWhenAbsent() throws {
        let store = InMemoryGuestIdentityStore()
        #expect(try store.load() == nil)
    }

    @Test func saveOverwrites() throws {
        let store = InMemoryGuestIdentityStore()
        try store.save(GuestIdentity(displayName: "Original", email: "a@x.com"))
        try store.save(GuestIdentity(displayName: "Updated", email: "b@y.com"))
        let loaded = try #require(try store.load())
        #expect(loaded.displayName == "Updated")
        #expect(loaded.email == "b@y.com")
    }

    @Test func clearRemovesBothFields() throws {
        let store = InMemoryGuestIdentityStore()
        try store.save(GuestIdentity(displayName: "Nate", email: "nate@example.com"))
        try store.clear()
        #expect(try store.load() == nil)
    }

    @Test func inMemoryStoreIsolatesBetweenInstances() throws {
        let storeA = InMemoryGuestIdentityStore()
        let storeB = InMemoryGuestIdentityStore()
        try storeA.save(GuestIdentity(displayName: "Alice", email: "a@a.com"))
        // B must not see A's write — proves the in-memory variant doesn't
        // share state, which the UI-test host relies on for clean per-run
        // injection.
        #expect(try storeB.load() == nil)
    }

    @Test func initialIdentityPrePopulates() throws {
        let store = InMemoryGuestIdentityStore(
            initial: GuestIdentity(displayName: "Pre", email: "p@p.com")
        )
        let loaded = try #require(try store.load())
        #expect(loaded.displayName == "Pre")
    }
}

// MARK: - Real Keychain (skipped on CI / package-test runs)

/// The real `KeychainGuestIdentityStore` smoke test is **disabled by
/// default**. Rationale:
///
/// - Swift Package Manager test runs (`swift test`) execute outside a
///   signed app bundle on macOS, so the keychain service queries either
///   fail with `errSecMissingEntitlement` (`-34018`) or hit the user's
///   *login* keychain in unpredictable ways.
/// - CI runners are even more inconsistent — Keychain access on Xcode
///   Cloud / GitHub Actions macOS images frequently throws permission
///   errors that have nothing to do with our code.
///
/// We rely on:
/// - The `InMemoryGuestIdentityStore` tests above for protocol-contract
///   coverage on every PR.
/// - The XCUITest smoke target (L3 in the test pyramid) for end-to-end
///   coverage of the real Keychain path inside a properly-signed host app.
///
/// The struct is exercised here for compile-time coverage of the
/// `Security`-framework wiring; the test below is intentionally
/// `Bool(false)`-gated rather than calling into `SecItem*` so a green run
/// only proves the type is constructible.
@Suite("KeychainGuestIdentityStore (compile-only smoke; live test runs in XCUITest)")
struct KeychainStoreCompileSmokeTests {

    @Test func canConstructAndIsSendable() {
        let store = KeychainGuestIdentityStore(service: "com.dutchovendaddy.DODApp.guest.test")
        // Statically prove the type satisfies the protocol — compile-time
        // assertion via the protocol-bound variable below.
        let _: any GuestIdentityStoring = store
        #expect(KeychainGuestIdentityStore.defaultService == "com.dutchovendaddy.DODApp.guest")
    }
}
