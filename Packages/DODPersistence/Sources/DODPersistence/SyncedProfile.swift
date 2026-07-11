import Foundation
import SwiftData

/// The SECOND model that mirrors to the user's CloudKit private database
/// (DUT-943 Scope A — profile sync, iOS ↔ iOS only). One row per signed-in
/// user, carrying the display name, email, and a single small avatar JPEG so
/// setting the profile picture on one device shows on the others.
///
/// **Per-user keying (DUT-371).** `ownerUserIdentifier` is the stable
/// Sign in with Apple / Google user id (`AppleAuthSession.userIdentifier` —
/// see `DODSupport/AppleAuthSession.swift`), NOT a device id. It is the sole
/// key a reader must filter on before ever applying a row to the local
/// profile — a shared iCloud account (e.g. Family Sharing) can carry rows
/// for MULTIPLE signed-in users in the same private database, and a row for
/// a different user must never bleed onto this device's profile. See
/// `ProfileSyncReconciler.isForCurrentUser` in `DODFeatureProfile` for the
/// testable guard, and `RecipeStore+SyncedProfile.swift` for the fetch that
/// filters by this field.
///
/// **CloudKit-clean (DOD-CRASH-1 invariants) — same contract as
/// `SyncedSavedRecipe`.** Every stored attribute is optional or carries a
/// default value, there is no `@Attribute(.unique)`, and no `@Relationship`.
/// Those are the two hard requirements for a model that opens under
/// `NSPersistentCloudKitContainer`; violating either makes the `.private`
/// container throw at open. `init` always overwrites the defaults with real
/// values; defaults are not part of the Core Data version hash, so the
/// additive V6 -> V7 migration that introduces this entity stays lightweight.
///
/// **Small avatar, not a cache blob.** `photoData` is the single current
/// avatar JPEG (the SAME 512×512 @ 0.85 quality derivative
/// `ProfilePhotoStore` already writes locally — see
/// `DODFeatureProfile/ProfileSyncCoordinator.swift`), typically 50–150 KB.
/// This is deliberately NOT a photo history / cache: there is exactly one
/// row per user and each save overwrites `photoData` in place, unlike the
/// DUT-35 `CachedImage` over-broad-mirror mistake that crashed the mirror on
/// a save-then-navigate path.
///
/// **Last-writer-wins.** `updatedAt` is the merge key a reader compares
/// against the local device's own last-local-edit timestamp
/// (`ProfileSyncCoordinator.localUpdatedAtKey`) to decide whether an incoming
/// synced row should overwrite the local profile. See
/// `ProfileSyncReconciler.winner(localUpdatedAt:remoteUpdatedAt:)`.
@Model
public final class SyncedProfile {

    /// The signed-in Apple/Google user id this row belongs to. The PER-USER
    /// key — see the type header. Empty string is not a valid owner (no
    /// signed-in user), but is the CloudKit-clean default value; every write
    /// path (`RecipeStore.upsertSyncedProfile`) requires a real,
    /// non-blank identifier before inserting a row.
    public var ownerUserIdentifier: String = ""

    /// Mirrors `UserProfile.displayName`.
    public var displayName: String = ""

    /// Mirrors `UserProfile.email`.
    public var email: String = ""

    /// The current avatar JPEG bytes, or `nil` if the user has no photo set.
    /// Kept small and singular — see the type header.
    public var photoData: Data?

    /// Last-writer-wins merge timestamp — see the type header.
    public var updatedAt = Date.distantPast

    public init(
        ownerUserIdentifier: String,
        displayName: String,
        email: String,
        photoData: Data? = nil,
        updatedAt: Date = .now
    ) {
        self.ownerUserIdentifier = ownerUserIdentifier
        self.displayName = displayName
        self.email = email
        self.photoData = photoData
        self.updatedAt = updatedAt
    }
}
