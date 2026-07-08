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
/// DUT-701 — which auth provider issued a persisted session. ``AppleAuthSession``
/// is a provider-neutral model reused by both Sign in with Apple and Sign in with
/// Google; the Apple credential-state validator must only poll Apple-issued
/// sessions, so the provider is recorded here.
public enum AuthProvider: String, Sendable, Hashable {
    case apple
    case google
}

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

    /// The long-lived Apple **refresh token**, obtained by exchanging the
    /// one-time `authorizationCode` server-side at sign-in (the SiwA revoke
    /// Worker, DUT-98). Stored so account deletion can later **revoke** it —
    /// the App Store 5.1.1(v) requirement for Sign in with Apple. `nil` when
    /// the exchange didn't run (no revoke Worker configured, or a re-auth that
    /// reused the existing session). Device-local, like the rest of the session.
    public let refreshToken: String?

    /// DUT-701 — which auth provider issued this session. Defaults to `.apple`
    /// so every existing call site and legacy persisted session (which predate
    /// this field) keeps behaving as an Apple session; only the Google sign-in
    /// path passes `.google` explicitly.
    public let provider: AuthProvider

    public init(
        userIdentifier: String,
        displayName: String? = nil,
        email: String? = nil,
        refreshToken: String? = nil,
        provider: AuthProvider = .apple
    ) {
        self.userIdentifier = userIdentifier
        self.displayName = displayName
        self.email = email
        self.refreshToken = refreshToken
        self.provider = provider
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

    /// DUT-506 — a save was attempted with an empty / whitespace-only
    /// `userIdentifier`. The identifier is the session's primary key; an empty
    /// one makes `hasSession` true for a phantom session and collides across
    /// users (every empty id compares equal), so the store rejects it at the
    /// boundary rather than persisting a `""`-keyed row.
    case emptyUserIdentifier
}

/// DUT-506 — the shared "is this a real, stable identifier?" test used to reject
/// an empty / whitespace-only `userIdentifier` at every boundary (the session
/// store save/load and the ``AppleProfileSignIn`` entry point). Mirrors the
/// `GIDSignInProvider` guard (`!identifier.isEmpty`) on the Google side (DUT-285).
extension String {
    public var isBlankAppleIdentifier: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
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
    static let refreshTokenAccount = "refresh-token"
    static let providerAccount = "auth-provider"

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
        // DUT-506 — a blank id must never surface as a "valid" session even if a
        // legacy / corrupt row wrote one: treat it as no session at all.
        guard !userIdentifier.isBlankAppleIdentifier else {
            return nil
        }
        // DUT-701 — a missing provider row is a legacy session written before the
        // field existed; those are Apple sessions, so default to `.apple`.
        let providerRaw = try readString(account: Self.providerAccount)
        let provider = providerRaw.flatMap(AuthProvider.init(rawValue:)) ?? .apple
        return AppleAuthSession(
            userIdentifier: userIdentifier,
            displayName: try readString(account: Self.displayNameAccount),
            email: try readString(account: Self.emailAccount),
            refreshToken: try readString(account: Self.refreshTokenAccount),
            provider: provider
        )
    }

    public func save(_ session: AppleAuthSession) throws {
        // DUT-506 — reject a blank primary key at the boundary so the store can
        // NEVER surface a `""`-keyed session, even if a future caller forgets the
        // upstream guard (defense in depth for the empty-id sign-in bug).
        guard !session.userIdentifier.isBlankAppleIdentifier else {
            throw AppleAuthError.emptyUserIdentifier
        }
        try writeString(session.userIdentifier, account: Self.userIdentifierAccount)
        try writeOptional(session.displayName, account: Self.displayNameAccount)
        try writeOptional(session.email, account: Self.emailAccount)
        try writeOptional(session.refreshToken, account: Self.refreshTokenAccount)
        try writeString(session.provider.rawValue, account: Self.providerAccount)
    }

    public func clear() throws {
        try delete(account: Self.userIdentifierAccount)
        try delete(account: Self.displayNameAccount)
        try delete(account: Self.emailAccount)
        try delete(account: Self.refreshTokenAccount)
        try delete(account: Self.providerAccount)
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
        // DUT-506 — mirror the Keychain store: a blank id is never a session.
        guard let stored, !stored.userIdentifier.isBlankAppleIdentifier else {
            return nil
        }
        return stored
    }

    public func save(_ session: AppleAuthSession) throws {
        lock.lock()
        defer { lock.unlock() }
        // DUT-506 — reject a blank primary key at the boundary, exactly like the
        // Keychain store, so the fake enforces the same invariant in tests.
        guard !session.userIdentifier.isBlankAppleIdentifier else {
            throw AppleAuthError.emptyUserIdentifier
        }
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
