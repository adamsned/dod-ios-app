import Foundation

/// A single user's synced profile row as read from (or about to be written
/// to) the CloudKit-mirrored `SyncedProfile` store (DUT-943 Scope A).
/// Provider-neutral `Sendable` DTO — `DODFeatureProfile` has no dependency on
/// `DODPersistence` / SwiftData, so this is the shape the App target's
/// `LiveProfileSyncStore` adapter translates `RecipeStore`'s
/// `SyncedProfileSnapshot` into and out of.
public struct SyncedProfileRecord: Sendable, Equatable {

    /// The signed-in Apple/Google user id this row belongs to (the PER-USER
    /// key — see ``ProfileSyncReconciler/isForCurrentUser(rowOwnerUserIdentifier:currentUserIdentifier:)``).
    public let ownerUserIdentifier: String

    /// Mirrors `UserProfile.displayName`.
    public let displayName: String

    /// Mirrors `UserProfile.email`.
    public let email: String

    /// The current avatar JPEG bytes, or `nil` if the user has no photo set.
    public let photoData: Data?

    /// Last-writer-wins merge timestamp — see ``ProfileSyncReconciler``.
    public let updatedAt: Date

    public init(
        ownerUserIdentifier: String,
        displayName: String,
        email: String,
        photoData: Data?,
        updatedAt: Date
    ) {
        self.ownerUserIdentifier = ownerUserIdentifier
        self.displayName = displayName
        self.email = email
        self.photoData = photoData
        self.updatedAt = updatedAt
    }
}

/// Read/write the CloudKit-mirrored per-user profile row (DUT-943 Scope A).
/// The App target's `LiveProfileSyncStore` is the production conformance,
/// bridging to `RecipeStore`'s `SyncedProfile` SwiftData model;
/// ``InMemoryProfileSyncStore`` backs unit tests.
public protocol ProfileSyncStoring: Sendable {

    /// Insert-or-update the row for `record.ownerUserIdentifier`. Production
    /// (`RecipeStore.upsertSyncedProfile`) collapses any CloudKit-duplicate
    /// rows to the newest by `updatedAt`, mirroring `SyncedSavedRecipe`'s
    /// DUT-650 collapse contract.
    func upsert(_ record: SyncedProfileRecord) async throws

    /// The row for `ownerUserIdentifier`, or `nil` if that user has never
    /// synced a profile.
    func fetch(ownerUserIdentifier: String) async throws -> SyncedProfileRecord?
}

/// In-memory ``ProfileSyncStoring`` for unit tests. Mirrors the
/// `InMemoryProfileStore` / `InMemoryProfilePhotoStore` posture in this
/// module — an `actor` so mutable state is isolated under strict
/// concurrency.
public actor InMemoryProfileSyncStore: ProfileSyncStoring {

    private var rowsByOwner: [String: SyncedProfileRecord] = [:]

    /// Records every ``upsert(_:)`` call in arrival order so tests can
    /// assert how many times (and with what) the mirror wrote.
    public private(set) var upsertedRecords: [SyncedProfileRecord] = []

    public init(seed: [SyncedProfileRecord] = []) {
        for record in seed {
            rowsByOwner[record.ownerUserIdentifier] = record
        }
    }

    public func upsert(_ record: SyncedProfileRecord) async throws {
        rowsByOwner[record.ownerUserIdentifier] = record
        upsertedRecords.append(record)
    }

    public func fetch(ownerUserIdentifier: String) async throws -> SyncedProfileRecord? {
        rowsByOwner[ownerUserIdentifier]
    }
}
