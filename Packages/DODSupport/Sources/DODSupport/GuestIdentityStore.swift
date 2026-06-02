import Foundation
import Security

/// On-device guest identity (display name + email) used when posting
/// comments and ratings to dutchovendaddy.com. Captured once on first write
/// (US-15 onboarding sheet), persisted in the iOS Keychain, replayed on
/// every subsequent comment/rating submission so the user doesn't have to
/// re-enter it. No password, no auth token, no account.
///
/// Spec trace: US-15 (guest identity), constitution §9 (Keychain-only
/// storage, never sent to TelemetryDeck).
public struct GuestIdentity: Sendable, Hashable {

    public let displayName: String
    public let email: String

    public init(displayName: String, email: String) {
        self.displayName = displayName
        self.email = email
    }
}

/// Failure modes for reading or writing the guest identity. Surfaced to the
/// caller so the comment/rating UI can show a sensible error when the
/// Keychain rejects a write (e.g. a corrupted ACL).
public enum GuestIdentityError: Error, Equatable {

    /// The underlying `SecItem*` call returned a non-success `OSStatus`.
    case keychainFailed(OSStatus)

    /// A row was present but its bytes were not valid UTF-8 — should be
    /// impossible since we only ever write strings, but guarded against
    /// data corruption.
    case decodingFailed
}

/// Read/write the on-device guest identity. Two implementations:
/// ``KeychainGuestIdentityStore`` for production and
/// ``InMemoryGuestIdentityStore`` for tests + UI-test injection.
public protocol GuestIdentityStoring: Sendable {

    /// Returns the stored identity, or `nil` if either the display name or
    /// email is missing. (Partial state is treated as "no identity" so the
    /// caller always re-prompts for both.)
    func load() throws -> GuestIdentity?

    /// Overwrite both fields. A second call with a new identity replaces
    /// the previous values.
    func save(_ identity: GuestIdentity) throws

    /// Remove both fields. Used by sign-out / "Forget me" UI in Settings.
    func clear() throws
}

// MARK: - Keychain implementation

/// Real `GuestIdentityStoring` backed by the iOS Keychain via the `Security`
/// framework directly (no third-party Keychain dep — constitution §3 default
/// answer is "no new dependency").
///
/// Storage layout: a single generic-password service identifier with two
/// distinct accounts (`display-name` and `email`). Reading is two
/// `SecItemCopyMatching` calls. Writing is a delete-then-add per field so
/// we don't have to handle the `errSecDuplicateItem` distinction at every
/// site.
///
/// Thread safety: `SecItem*` is safe to call from any thread, and the type
/// itself stores no mutable state — every call goes straight to the keychain.
/// That's why the type is a `struct` (value semantics) and `Sendable`.
///
/// Device scope: the item is DEVICE-LOCAL (`kSecAttrSynchronizable: false`),
/// so it never travels through iCloud Keychain. A name + email entered on one
/// device stays on that device; a brand-new commenter on a fresh device sees
/// empty fields, never another account's synced identity (DUT-30).
public struct KeychainGuestIdentityStore: GuestIdentityStoring {

    /// Conventional service identifier. The bundle ID matches the host app
    /// so the keychain entry shows up under the right app in System Settings.
    public static let defaultService = "com.dutchovendaddy.DODApp.guest"

    /// Account names used to distinguish the two fields under one service.
    static let displayNameAccount = "display-name"
    static let emailAccount = "email"

    private let service: String
    private let accessGroup: String?

    public init(
        service: String = KeychainGuestIdentityStore.defaultService,
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func load() throws -> GuestIdentity? {
        guard let name = try readString(account: Self.displayNameAccount),
            let email = try readString(account: Self.emailAccount)
        else { return nil }
        return GuestIdentity(displayName: name, email: email)
    }

    public func save(_ identity: GuestIdentity) throws {
        try writeString(identity.displayName, account: Self.displayNameAccount)
        try writeString(identity.email, account: Self.emailAccount)
    }

    public func clear() throws {
        try delete(account: Self.displayNameAccount)
        try delete(account: Self.emailAccount)
    }

    // MARK: - SecItem plumbing

    /// Common query attributes shared between read/write/delete calls.
    ///
    /// DUT-30: `kSecAttrSynchronizable` is pinned to `false` on EVERY call —
    /// add, read, and delete all funnel through here. Two reasons this has to
    /// be explicit and consistent:
    ///
    /// 1. The guest identity is a device-local convenience, not an account.
    ///    Without `kSecAttrSynchronizable: false` on `SecItemAdd`, an identity
    ///    saved while iCloud Keychain is on can sync to the user's other
    ///    devices — and, worse, another person sharing the same iCloud account
    ///    (Family Sharing, a shared Apple ID) has THEIR saved name + email
    ///    sync **onto this device**, where the DUT-28 prefill then surfaces a
    ///    stranger's identity on the comment form. That is exactly the build-9
    ///    report (an identity the owner never typed appearing pre-filled).
    /// 2. A bare query (no `kSecAttrSynchronizable`) only matches
    ///    NON-synchronizable items, so a row another device already synced in
    ///    would be invisible to our read yet still collide on add. Pinning the
    ///    attribute to `false` on read + delete too keeps add/read/update/
    ///    delete addressing the one, same, device-local row.
    ///
    /// Note: `kSecAttrAccessibleAfterFirstUnlock` (set on write) controls WHEN
    /// the item is readable, not WHETHER it syncs — only
    /// `kSecAttrSynchronizable` governs iCloud Keychain. Both are required.
    ///
    /// `static` + pure so ``GuestIdentityStoreTests`` can assert the device-
    /// local attributes without touching the real Keychain (`SecItem*` is
    /// unreliable under `swift test` outside a signed bundle — see the suite
    /// note). `accessGroup` is threaded through rather than read off `self`.
    static func baseQuery(service: String, account: String, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // Device-local only — never match or create an iCloud-synced row.
            kSecAttrSynchronizable as String: false,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    /// Attribute dictionary handed to `SecItemAdd`. Builds on ``baseQuery``
    /// (so it inherits the device-local `kSecAttrSynchronizable: false`) and
    /// layers the value bytes + after-first-unlock accessibility. `static` +
    /// pure for the same testability reason as ``baseQuery``.
    static func addAttributes(
        service: String,
        account: String,
        accessGroup: String?,
        value: String
    ) -> [String: Any] {
        var attributes = baseQuery(service: service, account: account, accessGroup: accessGroup)
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return attributes
    }

    /// Instance convenience wrapper over the `static` ``baseQuery`` so the
    /// `SecItem*` call sites stay terse.
    private func baseQuery(account: String) -> [String: Any] {
        Self.baseQuery(service: service, account: account, accessGroup: accessGroup)
    }

    private func readString(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw GuestIdentityError.decodingFailed }
            guard let string = String(data: data, encoding: .utf8) else {
                throw GuestIdentityError.decodingFailed
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw GuestIdentityError.keychainFailed(status)
        }
    }

    private func writeString(_ value: String, account: String) throws {
        // Delete first then add. SecItemUpdate exists but the delete-then-add
        // pattern is simpler to reason about (one happy path, no "did we
        // already have a row?" branch) and SecItemDelete returning
        // errSecItemNotFound is a no-op.
        try delete(account: account)

        // Accessible after first unlock and device-local (the add attributes
        // inherit `kSecAttrSynchronizable: false` from `baseQuery`), so the
        // row never reaches iCloud Keychain — a guest identity is
        // local-to-device by design (DUT-30). Accessibility and
        // synchronizability are independent attributes; both are needed.
        let attributes = Self.addAttributes(
            service: service,
            account: account,
            accessGroup: accessGroup,
            value: value
        )

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw GuestIdentityError.keychainFailed(status)
        }
    }

    private func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        // errSecItemNotFound is fine — clear() is idempotent.
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GuestIdentityError.keychainFailed(status)
        }
    }
}

// MARK: - In-memory implementation (tests + UI-test injection)

/// In-memory `GuestIdentityStoring` for unit tests and UI-test hosts where
/// touching the real Keychain would be flaky (CI runners) or leak state
/// between runs. Thread-safe via an internal lock so concurrent access from
/// view models in tests is well-defined.
public final class InMemoryGuestIdentityStore: GuestIdentityStoring, @unchecked Sendable {

    private let lock = NSLock()
    private var stored: GuestIdentity?

    public init(initial: GuestIdentity? = nil) {
        self.stored = initial
    }

    public func load() throws -> GuestIdentity? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    public func save(_ identity: GuestIdentity) throws {
        lock.lock()
        defer { lock.unlock() }
        stored = identity
    }

    public func clear() throws {
        lock.lock()
        defer { lock.unlock() }
        stored = nil
    }
}
