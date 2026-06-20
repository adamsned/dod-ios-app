import Foundation
import Security
import Testing

@testable import DODSupport

// MARK: - In-memory implementation (always runnable)

/// `InMemoryAppleAuthSessionStore` covers the protocol contract under unit
/// tests without touching the real Keychain. These run on every PR.
///
/// Spec trace: US-46 (Authentication — Phase a, Sign in with Apple), DUT-16.
@Suite("InMemoryAppleAuthSessionStore (US-46)")
struct InMemoryAppleAuthSessionStoreTests {

    @Test func roundTripSaveLoad() throws {
        let store = InMemoryAppleAuthSessionStore()
        let session = AppleAuthSession(
            userIdentifier: "001234.abcdef",
            displayName: "Ned Adams",
            email: "ned@example.com"
        )
        try store.save(session)
        #expect(try store.load() == session)
    }

    @Test func loadReturnsNilWhenAbsent() throws {
        #expect(try InMemoryAppleAuthSessionStore().load() == nil)
    }

    /// Apple releases name + email only on the FIRST authorization; every
    /// subsequent credential carries just the stable user identifier. A
    /// session with only `userIdentifier` is valid and must round-trip.
    @Test func sessionWithOnlyUserIdentifierRoundTrips() throws {
        let store = InMemoryAppleAuthSessionStore()
        let reauth = AppleAuthSession(userIdentifier: "001234.abcdef")
        try store.save(reauth)
        let loaded = try #require(try store.load())
        #expect(loaded.userIdentifier == "001234.abcdef")
        #expect(loaded.displayName == nil)
        #expect(loaded.email == nil)
    }

    @Test func saveOverwrites() throws {
        let store = InMemoryAppleAuthSessionStore()
        try store.save(AppleAuthSession(userIdentifier: "a", displayName: "Old", email: "old@x.com"))
        try store.save(AppleAuthSession(userIdentifier: "a", displayName: "New", email: "new@y.com"))
        let loaded = try #require(try store.load())
        #expect(loaded.displayName == "New")
        #expect(loaded.email == "new@y.com")
    }

    @Test func clearRemovesTheSession() throws {
        let store = InMemoryAppleAuthSessionStore()
        try store.save(AppleAuthSession(userIdentifier: "a", displayName: "Ned", email: "n@x.com"))
        try store.clear()
        #expect(try store.load() == nil)
    }

    @Test func storesIsolateBetweenInstances() throws {
        let storeA = InMemoryAppleAuthSessionStore()
        let storeB = InMemoryAppleAuthSessionStore()
        try storeA.save(AppleAuthSession(userIdentifier: "a"))
        #expect(try storeB.load() == nil)
    }

    @Test func initialSessionPrePopulates() throws {
        let store = InMemoryAppleAuthSessionStore(
            initial: AppleAuthSession(userIdentifier: "pre", displayName: "Pre")
        )
        #expect(try #require(try store.load()).userIdentifier == "pre")
    }

    /// A private-relay email (Hide My Email) is just a string to the store —
    /// it must round-trip verbatim so the comment/rating path can post against
    /// it. Documents the relay-address case the auth UI will surface.
    @Test func privateRelayEmailRoundTrips() throws {
        let store = InMemoryAppleAuthSessionStore()
        let relay = "abc123@privaterelay.appleid.com"
        try store.save(AppleAuthSession(userIdentifier: "a", email: relay))
        #expect(try #require(try store.load()).email == relay)
    }
}

// MARK: - Real Keychain (compile-only smoke; live test runs in XCUITest)

/// The real `KeychainAppleAuthSessionStore` is **not** exercised against
/// `SecItem*` here — `swift test` runs outside a signed bundle, where the
/// Keychain throws `errSecMissingEntitlement` (`-34018`) or hits the login
/// keychain unpredictably (same rationale as `KeychainGuestIdentityStore`).
/// The live round-trip belongs to the XCUITest L3 target inside the signed
/// host app; here we only prove the type is constructible + protocol-conformant.
@Suite("KeychainAppleAuthSessionStore (compile-only smoke)")
struct AppleAuthKeychainSmokeTests {

    @Test func canConstructAndIsSendable() {
        let store = KeychainAppleAuthSessionStore(service: "com.dutchovendaddy.DODApp.appleauth.test")
        let _: any AppleAuthSessionStoring = store
        #expect(KeychainAppleAuthSessionStore.defaultService == "com.dutchovendaddy.DODApp.appleauth")
    }
}

// MARK: - Device-local attribute contract (DUT-30 parity)

/// The Apple session is DEVICE-LOCAL for the same reason the guest identity is
/// (DUT-30): a session must never sync over iCloud Keychain, or a shared Apple
/// ID / Family Sharing could surface one person's signed-in session on
/// another's device. Cross-device continuity is the backend phase's job
/// (DUT-16 Phase d), not iCloud Keychain. These assert the pure attribute
/// builders (the live round-trip is an XCUITest concern — see the suite note).
@Suite("KeychainAppleAuthSessionStore device-local attributes (DUT-30)")
struct AppleAuthKeychainDeviceLocalTests {

    private static let service = "com.dutchovendaddy.DODApp.appleauth.test"

    @Test func baseQueryIsNonSynchronizable() {
        let query = KeychainAppleAuthSessionStore.baseQuery(
            service: Self.service,
            account: KeychainAppleAuthSessionStore.userIdentifierAccount,
            accessGroup: nil
        )
        #expect(query[kSecAttrSynchronizable as String] as? Bool == false)
        // Must be the explicit non-synchronizable flag, never the "match
        // either" wildcard that would let an iCloud-synced row through.
        #expect(
            (query[kSecAttrSynchronizable as String] as? String)
                != (kSecAttrSynchronizableAny as String)
        )
    }

    @Test func addAttributesAreNonSynchronizableAndAccessibleAfterFirstUnlock() {
        let attributes = KeychainAppleAuthSessionStore.addAttributes(
            service: Self.service,
            account: KeychainAppleAuthSessionStore.userIdentifierAccount,
            accessGroup: nil,
            value: "001234.abcdef"
        )
        #expect(attributes[kSecAttrSynchronizable as String] as? Bool == false)
        #expect(
            (attributes[kSecAttrAccessible as String] as? String)
                == (kSecAttrAccessibleAfterFirstUnlock as String)
        )
        #expect(attributes[kSecValueData as String] as? Data == Data("001234.abcdef".utf8))
    }

    @Test func accessGroupIsPreservedAlongsideDeviceLocalFlag() {
        let group = "ABCDE12345.com.dutchovendaddy.shared"
        let query = KeychainAppleAuthSessionStore.baseQuery(
            service: Self.service,
            account: KeychainAppleAuthSessionStore.emailAccount,
            accessGroup: group
        )
        #expect(query[kSecAttrAccessGroup as String] as? String == group)
        #expect(query[kSecAttrSynchronizable as String] as? Bool == false)
    }
}
