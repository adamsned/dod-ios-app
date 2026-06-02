import Foundation
import Security
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

// MARK: - Device-local attribute contract (DUT-30)

/// DUT-30: the build-9 report had "Spencer Adams" pre-filling the comment
/// form on a device that never typed it — a guest identity that synced in
/// over iCloud Keychain from another Apple ID that had also commented on the
/// recipe. The fix makes the Keychain item DEVICE-LOCAL: every `SecItem*`
/// query (add / read / update / delete) must pin
/// `kSecAttrSynchronizable: false` so a value saved on one device never
/// appears on another.
///
/// These tests assert on the pure attribute builders rather than calling
/// `SecItem*`, because `swift test` runs outside a signed bundle where the
/// real Keychain is unreliable (see the suite note above). Asserting the
/// dictionaries is the deterministic way to lock the device-local contract on
/// every PR; the XCUITest L3 target exercises the live round-trip.
@Suite("KeychainGuestIdentityStore device-local attributes (DUT-30)")
struct KeychainStoreDeviceLocalTests {

    private static let service = "com.dutchovendaddy.DODApp.guest.test"

    /// The shared base query (used by read + delete) is pinned non-syncable
    /// AND uses the boolean `false`, not a present-but-truthy value — a query
    /// that omitted the key, or set it to `kSecAttrSynchronizableAny`, would
    /// match iCloud-synced rows and reintroduce the cross-device leak.
    @Test func baseQueryIsNonSynchronizable() {
        let query = KeychainGuestIdentityStore.baseQuery(
            service: Self.service,
            account: KeychainGuestIdentityStore.emailAccount,
            accessGroup: nil
        )
        let sync = try? #require(query[kSecAttrSynchronizable as String])
        #expect(sync as? Bool == false)
        // It must be an explicit non-synchronizable flag, never the
        // "match either" wildcard that would let a synced row through.
        #expect((query[kSecAttrSynchronizable as String] as? String) != (kSecAttrSynchronizableAny as String))
    }

    /// The add attributes inherit the device-local flag AND keep the
    /// after-first-unlock accessibility. Accessibility and synchronizability
    /// are independent: the pre-fix code set accessibility and *assumed* that
    /// stopped iCloud sync — it does not. Both must be present.
    @Test func addAttributesAreNonSynchronizableAndAccessibleAfterFirstUnlock() {
        let attributes = KeychainGuestIdentityStore.addAttributes(
            service: Self.service,
            account: KeychainGuestIdentityStore.displayNameAccount,
            accessGroup: nil,
            value: "Ned"
        )
        #expect(attributes[kSecAttrSynchronizable as String] as? Bool == false)
        #expect(
            (attributes[kSecAttrAccessible as String] as? String)
                == (kSecAttrAccessibleAfterFirstUnlock as String)
        )
        // The bytes we add are the UTF-8 of the value.
        #expect(attributes[kSecValueData as String] as? Data == Data("Ned".utf8))
    }

    /// Read, add, AND delete must address the SAME device-local row: all
    /// three carry `kSecAttrSynchronizable: false` so an identity saved on one
    /// device is never read, updated, or deleted against an iCloud-synced
    /// twin. (`delete` and `read` both go through `baseQuery`; `add` through
    /// `addAttributes`, which is built on `baseQuery`.)
    @Test func addAndQueryAgreeOnDeviceLocalFlag() {
        let queryFlag =
            KeychainGuestIdentityStore.baseQuery(
                service: Self.service,
                account: KeychainGuestIdentityStore.emailAccount,
                accessGroup: nil
            )[kSecAttrSynchronizable as String] as? Bool
        let addFlag =
            KeychainGuestIdentityStore.addAttributes(
                service: Self.service,
                account: KeychainGuestIdentityStore.emailAccount,
                accessGroup: nil,
                value: "ned@example.com"
            )[kSecAttrSynchronizable as String] as? Bool
        #expect(queryFlag == false)
        #expect(addFlag == false)
        #expect(queryFlag == addFlag)
    }

    /// When an access group is configured it is threaded through unchanged
    /// while the device-local flag stays pinned — the two attributes are
    /// orthogonal and must not clobber each other.
    @Test func accessGroupIsPreservedAlongsideDeviceLocalFlag() {
        let group = "ABCDE12345.com.dutchovendaddy.shared"
        let query = KeychainGuestIdentityStore.baseQuery(
            service: Self.service,
            account: KeychainGuestIdentityStore.emailAccount,
            accessGroup: group
        )
        #expect(query[kSecAttrAccessGroup as String] as? String == group)
        #expect(query[kSecAttrSynchronizable as String] as? Bool == false)
    }
}
