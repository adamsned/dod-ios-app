import Foundation
import Security

/// Failure modes for reading / writing the on-device user profile.
/// Surfaced so the edit view can render a humane prompt instead of a
/// silent drop (matches the ``GuestIdentityError`` shape in `DODSupport`).
public enum ProfileStoreError: Error, Equatable {

    /// The underlying `SecItem*` call returned a non-success `OSStatus`.
    case keychainFailed(OSStatus)

    /// A row was present but its bytes did not decode as a valid JSON
    /// ``UserProfile`` (data corruption / older schema).
    case decodingFailed

    /// One of the validation rules in ``UserProfile/validateDisplayName(_:)``
    /// or ``UserProfile/validateEmail(_:)`` failed.
    case validation(UserProfile.ValidationError)
}

/// Read / write / clear the on-device ``UserProfile``. Two implementations:
/// ``KeychainProfileStore`` for production and ``InMemoryProfileStore`` for
/// tests + UI-test injection.
///
/// Spec trace: US-44 AC-44.1..AC-44.7; CL-136.
public protocol ProfileStoring: Sendable {

    /// Returns the stored profile, or `nil` if no profile has been saved
    /// yet (the guest-mode default).
    func load() async -> UserProfile?

    /// Persist the profile (validates display name + email; throws
    /// ``ProfileStoreError/validation(_:)`` on a malformed input,
    /// ``ProfileStoreError/keychainFailed(_:)`` on a SecItem failure).
    func save(_ profile: UserProfile) async throws

    /// Remove the profile entry. Used by Sign Out + Delete Profile
    /// (identical behavior for local-only v1 per the locked decision).
    /// Idempotent — a "not found" status is treated as success.
    func clear() async throws

    /// Convenience read used by Phase c's gated write surfaces (Ratings
    /// popup, etc.) to skip the gate when a profile already exists.
    var hasProfile: Bool { get async }
}

// MARK: - Keychain implementation

/// Production ``ProfileStoring`` backed by the iOS Keychain via the
/// `Security` framework directly (no third-party Keychain dep —
/// constitution §3 default answer is "no new dependency").
///
/// Storage layout: a single generic-password row under service
/// `com.dutchovendaddy.DODApp.profile.v1` (account `"profile"`) with the
/// JSON-encoded ``UserProfile`` as the value. Reading is one
/// `SecItemCopyMatching`; writing is delete-then-add so we never have to
/// handle `errSecDuplicateItem`. Accessible after first unlock
/// (`kSecAttrAccessibleAfterFirstUnlock`) so a background widget refresh
/// that needs the profile's `id` doesn't block on a locked device.
///
/// **iCloud Keychain posture.** The profile entry is `kSecAttrSynchronizable:
/// false` (device-local), matching the ``KeychainGuestIdentityStore`` posture
/// from US-15 / CL-15. The locked decision is "local-only v1" — survives
/// reinstall via iCloud Keychain *backup* (if the user has it on at the OS
/// level), but is NOT iCloud-Keychain-*synced* across devices. When DUT-16
/// adds backend state, the Sign Out vs Delete Profile semantics diverge
/// (sign-out keeps server data, delete nukes it); today both clear this
/// row.
///
/// Thread safety: `SecItem*` is safe to call from any thread, and the
/// actor stores no mutable state — every call goes straight to the
/// keychain. The `actor` declaration matches the existing concurrency
/// style (RecipeStore uses `actor` / `@ModelActor` heavily).
public actor KeychainProfileStore: ProfileStoring {

    /// Conventional service identifier. The bundle ID matches the host app
    /// so the keychain entry shows up under the right app in System
    /// Settings → Passwords. The `.profile.v1` suffix mirrors the
    /// `dod.cloudkit.syncOptInV1` / `dod.settings.downloadVoiceTipDismissedV1`
    /// pattern so a future schema bump can migrate without colliding.
    public static let defaultService = "com.dutchovendaddy.DODApp.profile.v1"

    /// Single-row account name. Distinguishes this row from any other
    /// future generic-password row under the same service identifier.
    static let profileAccount = "profile"

    private let service: String
    private let accessGroup: String?

    public init(
        service: String = KeychainProfileStore.defaultService,
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }

    // MARK: - ProfileStoring

    public func load() async -> UserProfile? {
        do {
            guard let data = try readData() else { return nil }
            return try? JSONDecoder().decode(UserProfile.self, from: data)
        } catch {
            return nil
        }
    }

    public func save(_ profile: UserProfile) async throws {
        // Pre-flight validation so a caller that bypasses the edit form's
        // Done-button gate (a programmatic save, a future test fixture)
        // still cannot persist a blank name/email row — the network-layer
        // backstop pattern from CL-134 / DUT-7's empty-identity guard.
        do {
            _ = try UserProfile.validateDisplayName(profile.displayName)
            _ = try UserProfile.validateEmail(profile.email)
        } catch let validationError as UserProfile.ValidationError {
            throw ProfileStoreError.validation(validationError)
        }
        let data = try JSONEncoder().encode(profile)
        try writeData(data)
    }

    public func clear() async throws {
        try deleteRow()
    }

    public var hasProfile: Bool {
        get async { await load() != nil }
    }

    // MARK: - SecItem plumbing

    /// Common query attributes shared between read/write/delete calls.
    /// Pinned `kSecAttrSynchronizable: false` so the profile row is
    /// addressed identically on add / read / delete — matches the
    /// ``KeychainGuestIdentityStore`` pattern + the CL-15 / DUT-30
    /// device-local posture rationale.
    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.profileAccount,
            // Device-local only — never match or create an iCloud-synced
            // row. Profile is intentionally local-only in v1 per CL-136
            // (iCloud Keychain *backup* still restores the row after a
            // wipe-and-reinstall on the same Apple ID, which is the
            // desired survives-reinstall behavior).
            kSecAttrSynchronizable as String: false,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    private func readData() throws -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw ProfileStoreError.keychainFailed(status)
        }
    }

    private func writeData(_ data: Data) throws {
        // Delete-then-add is simpler to reason about than SecItemUpdate
        // (one happy path, no "did we already have a row?" branch); the
        // delete is a no-op when the row doesn't exist.
        try deleteRow()
        var attributes = baseQuery()
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ProfileStoreError.keychainFailed(status)
        }
    }

    private func deleteRow() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        // errSecItemNotFound is fine — clear() is idempotent.
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ProfileStoreError.keychainFailed(status)
        }
    }
}

// MARK: - In-memory implementation (tests + UI-test injection)

/// In-memory ``ProfileStoring`` for unit tests and UI-test hosts where
/// touching the real Keychain would be flaky (CI runners) or leak state
/// between runs. Modeled as an `actor` so its mutable state is isolated
/// for the strict-concurrency build (`SWIFT_STRICT_CONCURRENCY=complete`
/// project-wide) without needing an `@unchecked Sendable` lock dance.
public actor InMemoryProfileStore: ProfileStoring {

    private var stored: UserProfile?

    public init(initial: UserProfile? = nil) {
        self.stored = initial
    }

    public func load() async -> UserProfile? {
        stored
    }

    public func save(_ profile: UserProfile) async throws {
        // Same pre-flight validation as the Keychain store so the test
        // fakes catch a malformed input the same way production does.
        do {
            _ = try UserProfile.validateDisplayName(profile.displayName)
            _ = try UserProfile.validateEmail(profile.email)
        } catch let validationError as UserProfile.ValidationError {
            throw ProfileStoreError.validation(validationError)
        }
        stored = profile
    }

    public func clear() async throws {
        stored = nil
    }

    public var hasProfile: Bool {
        get async { stored != nil }
    }
}
