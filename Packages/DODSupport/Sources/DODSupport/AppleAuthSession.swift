import Foundation
import Security

/// On-device record of a completed **Sign in with Apple** authentication
/// (US-46 / DUT-16 Phase a). Persists the stable Apple user identifier plus
/// the display name + email Apple hands back — but **only on the very first
/// authorization for this Apple ID**; every subsequent sign-in returns a
/// credential whose name/email are `nil`, which is why both are optional here.
///
/// This is the local foundation of the login feature: it replaces the
/// anonymous guest UUID (US-15) as the comment/rating identity once a user
/// signs in, and survives reinstall via the Keychain. Cross-device sync of
/// this session through a backend is a later phase (DUT-16 Phase d), gated on
/// the backend-provider decision; this slice is entirely on-device and
/// backend-independent.
///
/// Spec trace: US-46 (Authentication — Phase a, Sign in with Apple),
/// constitution §9 (Keychain-only, never sent to TelemetryDeck), CL-189.
public struct AppleAuthSession: Sendable, Hashable {

    /// The stable, opaque Apple user identifier
    /// (`ASAuthorizationAppleIDCredential.user`). Constant for a given Apple
    /// ID + app team across devices and reinstalls — the durable primary key.
    public let userIdentifier: String

    /// The user's display name, formatted from the credential's
    /// `fullName: PersonNameComponents?`. `nil` on every sign-in after the
    /// first (Apple only releases the name once), or when the user declined
    /// to share it.
    public let displayName: String?

    /// The user's email — a real address, or an Apple private-relay address
    /// (`…@privaterelay.appleid.com`) when the user chose "Hide My Email".
    /// `nil` on every sign-in after the first, or when withheld.
    public let email: String?

    public init(userIdentifier: String, displayName: String? = nil, email: String? = nil) {
        self.userIdentifier = userIdentifier
        self.displayName = displayName
        self.email = email
    }
}

/// Failure modes for reading or writing the Apple auth session. Mirrors
/// ``GuestIdentityError`` so the auth UI can surface a sensible message when
/// the Keychain rejects a write.
public enum AppleAuthError: Error, Equatable {

    /// The underlying `SecItem*` call returned a non-success `OSStatus`.
    case keychainFailed(OSStatus)

    /// A row was present but its bytes were not valid UTF-8 — should be
    /// impossible since we only ever write strings, guarded against corruption.
    case decodingFailed
}

/// Read/write the on-device Apple auth session. Two implementations:
/// ``KeychainAppleAuthSessionStore`` for production and
/// ``InMemoryAppleAuthSessionStore`` for tests + UI-test injection.
///
/// **Persistence contract — the store is a dumb, exact persist.** ``save(_:)``
/// writes exactly the session given: a `nil` `displayName`/`email` clears that
/// field. Because Apple only releases the name + email on the *first*
/// authorization, the auth coordinator (a later DUT-16 slice) is responsible
/// for *merging* — loading the existing session and carrying its name/email
/// forward when a re-auth credential arrives with `nil` values — before
/// calling ``save(_:)``. Keeping the merge out of the store keeps this a clean,
/// predictable primitive (what you save is what you load).
public protocol AppleAuthSessionStoring: Sendable {

    /// The stored session, or `nil` when no `userIdentifier` is present.
    /// (`displayName`/`email` load independently and may each be `nil`.)
    func load() throws -> AppleAuthSession?

    /// Persist `session` exactly: `userIdentifier` is written; a non-`nil`
    /// `displayName`/`email` is written, a `nil` one is cleared.
    func save(_ session: AppleAuthSession) throws

    /// Remove every field. Used by Settings → Account → Sign Out and the
    /// in-app Delete Account flow (App Store Guideline 5.1.1(v)).
    func clear() throws
}

// MARK: - Keychain implementation

/// Real ``AppleAuthSessionStoring`` backed by the iOS Keychain via the
/// `Security` framework directly (no third-party dep — constitution §3).
/// Layout mirrors ``KeychainGuestIdentityStore``: one generic-password service
/// with three accounts (`user-identifier`, `display-name`, `email`).
///
/// **Device-local (`kSecAttrSynchronizable: false`).** Like the guest identity
/// (DUT-30), the session never travels through iCloud Keychain, so a shared
/// Apple ID / Family Sharing can't surface one person's session on another's
/// device. Cross-device continuity is the job of the backend phase (DUT-16
/// Phase d), not iCloud Keychain.
public struct KeychainAppleAuthSessionStore: AppleAuthSessionStoring {

    /// Conventional service identifier (bundle-id-scoped so it shows under the
    /// right app in System Settings).
    public static let defaultService = "com.dutchovendaddy.DODApp.appleauth"

    /// Account names distinguishing the three fields under one service.
    static let userIdentifierAccount = "user-identifier"
    static let displayNameAccount = "display-name"
    static let emailAccount = "email"

    private let service: String
    private let accessGroup: String?

    public init(
        service: String = KeychainAppleAuthSessionStore.defaultService,
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func load() throws -> AppleAuthSession? {
        // `userIdentifier` is the required primary key: no id → no session.
        // Name + email load independently and are legitimately optional.
        guard let userIdentifier = try readString(account: Self.userIdentifierAccount) else {
            return nil
        }
        return AppleAuthSession(
            userIdentifier: userIdentifier,
            displayName: try readString(account: Self.displayNameAccount),
            email: try readString(account: Self.emailAccount)
        )
    }

    public func save(_ session: AppleAuthSession) throws {
        try writeString(session.userIdentifier, account: Self.userIdentifierAccount)
        try writeOptional(session.displayName, account: Self.displayNameAccount)
        try writeOptional(session.email, account: Self.emailAccount)
    }

    public func clear() throws {
        try delete(account: Self.userIdentifierAccount)
        try delete(account: Self.displayNameAccount)
        try delete(account: Self.emailAccount)
    }

    // MARK: - SecItem plumbing

    /// Shared query attributes. `kSecAttrSynchronizable: false` is pinned on
    /// every call (add/read/delete) for the same DUT-30 device-local reasons
    /// ``KeychainGuestIdentityStore/baseQuery(service:account:accessGroup:)``
    /// documents. `static` + pure so the test suite can assert the
    /// device-local attributes without touching the real Keychain (`SecItem*`
    /// is unreliable under `swift test` outside a signed bundle).
    static func baseQuery(service: String, account: String, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    /// Attributes handed to `SecItemAdd`. Builds on ``baseQuery`` (inheriting
    /// the device-local `kSecAttrSynchronizable: false`) + the value bytes +
    /// after-first-unlock accessibility. `static` + pure for testability.
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
            guard let data = item as? Data else { throw AppleAuthError.decodingFailed }
            guard let string = String(data: data, encoding: .utf8) else {
                throw AppleAuthError.decodingFailed
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw AppleAuthError.keychainFailed(status)
        }
    }

    /// Write a non-optional field (delete-then-add, like the guest store).
    private func writeString(_ value: String, account: String) throws {
        try delete(account: account)
        let attributes = Self.addAttributes(
            service: service,
            account: account,
            accessGroup: accessGroup,
            value: value
        )
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppleAuthError.keychainFailed(status)
        }
    }

    /// Write an optional field: persist when present, clear when `nil`, so a
    /// saved session reads back exactly as written (the dumb-persist contract).
    private func writeOptional(_ value: String?, account: String) throws {
        if let value {
            try writeString(value, account: account)
        } else {
            try delete(account: account)
        }
    }

    private func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppleAuthError.keychainFailed(status)
        }
    }
}

// MARK: - In-memory implementation (tests + UI-test injection)

/// In-memory ``AppleAuthSessionStoring`` for unit tests + UI-test hosts where
/// the real Keychain is flaky (CI runners) or leaks state between runs.
/// Thread-safe via an internal lock. Mirrors ``InMemoryGuestIdentityStore``.
public final class InMemoryAppleAuthSessionStore: AppleAuthSessionStoring, @unchecked Sendable {

    private let lock = NSLock()
    private var stored: AppleAuthSession?

    public init(initial: AppleAuthSession? = nil) {
        self.stored = initial
    }

    public func load() throws -> AppleAuthSession? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    public func save(_ session: AppleAuthSession) throws {
        lock.lock()
        defer { lock.unlock() }
        // Match the Keychain store's exact-persist contract: a nil name/email
        // is stored as nil (the in-memory value type already captures this).
        stored = session
    }

    public func clear() throws {
        lock.lock()
        defer { lock.unlock() }
        stored = nil
    }
}
