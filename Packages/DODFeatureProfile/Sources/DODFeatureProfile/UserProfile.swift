import Foundation

/// On-device user profile (display name + email + optional photo filename)
/// stored locally in the Keychain. Phase a of DUT-36 (US-44).
///
/// **Bridge to US-15 guest identity.** The `id` field is the canonical UUID
/// the app uses to attribute a comment/rating to "this device's commenter."
/// When the user creates a profile, the existing on-device guest UUID
/// (US-15 / CL-15 — stored alongside the name + email in the guest-identity
/// Keychain row) is reused as `Profile.id` so previously-submitted guest
/// comments stay associated with the same UUID. Old guest comments are NOT
/// retroactively re-attributed to the new profile (locked decision per
/// CL-136); they remain attributed to the guest identity that posted them.
/// Only new comments after profile creation use the profile.
///
/// **Storage.** Local-only Keychain entry (single JSON-encoded record under
/// service `com.dutchovendaddy.DODApp.profile.v1`). Survives reinstall via
/// iCloud Keychain backup (NOT iCloud Keychain *sync* — the entry is device-
/// local; only the OS-managed iCloud Keychain backup, if the user has it
/// on, restores it after wipe-and-reinstall). The photo file lives in the
/// app's Documents directory (Phase b — `photoFilename` stubbed nil in
/// Phase a).
///
/// Spec trace: US-44 AC-44.1..AC-44.7; CL-136.
public struct UserProfile: Codable, Equatable, Sendable {

    /// Stable identity for "this device's commenter." Bridges to the US-15
    /// guest UUID so old guest comments stay associated with the same id.
    public let id: UUID

    /// Required. 1+ non-whitespace characters. Validated via
    /// ``validateDisplayName(_:)`` before save.
    public var displayName: String

    /// Required. Basic regex-validated form (`^[^@\s]+@[^@\s]+\.[^@\s]+$`).
    /// Validated via ``validateEmail(_:)`` before save.
    public var email: String

    /// Phase a stubs this as `nil`; Phase b (photo picker + crop) populates
    /// it with the on-disk filename inside the app's Documents directory.
    public var photoFilename: String?

    public init(
        id: UUID,
        displayName: String,
        email: String,
        photoFilename: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.photoFilename = photoFilename
    }

    // MARK: - Validation

    /// Failure modes for ``UserProfile`` validation. Surfaced to the
    /// caller so the edit view can render a humane prompt instead of
    /// silently dropping a save.
    public enum ValidationError: Error, Equatable {

        case displayNameEmpty
        case emailEmpty
        case emailInvalid
    }

    /// Returns the trimmed display name if non-empty; throws
    /// ``ValidationError/displayNameEmpty`` otherwise. Used both by the
    /// edit form's Done-button gate and by ``ProfileStore/save(_:)``'s
    /// pre-flight check so a bypass at one layer is caught at the other.
    public static func validateDisplayName(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.displayNameEmpty }
        return trimmed
    }

    /// Returns the trimmed email if it matches a basic well-formed pattern
    /// (`^[^@\s]+@[^@\s]+\.[^@\s]+$`); throws ``ValidationError/emailEmpty``
    /// for an empty input or ``ValidationError/emailInvalid`` for a
    /// malformed one. Intentionally lightweight — server-side validation
    /// is authoritative; this is a client-side first-pass guard so
    /// `author_email=""` / `"foo"` never reach the network (matches the
    /// CL-134 / DUT-7 empty-identity guard rationale on the comment path).
    public static func validateEmail(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.emailEmpty }
        guard Self.emailRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil else {
            throw ValidationError.emailInvalid
        }
        return trimmed
    }

    /// `^[^@\s]+@[^@\s]+\.[^@\s]+$` — the locked basic email shape per
    /// CL-136. Compiled once at type-load so per-keystroke validation in
    /// the edit form is cheap. The intentional looseness (no IDN, no
    /// length cap, no TLD allow-list) matches the locked decision: client-
    /// side guard is "obviously well-formed," authoritative validation
    /// happens server-side when a comment is posted.
    private static let emailRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#)
    }()
}
