import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// DUT-943 Scope A: `RecipeStore`'s synced-profile upsert/read API. Runs on
/// the same two-configuration in-memory container the app uses (both stores
/// `.none` in tests) — see `SyncedSavedRecipeTests` for the sibling suite
/// this mirrors.
@Suite("RecipeStore synced profile (DUT-943 Scope A)")
struct SyncedProfileTests {

    @Test("Upsert writes a new row; snapshot reads it back")
    func upsertWritesNewRow() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await store.upsertSyncedProfile(
            ownerUserIdentifier: "user-1",
            displayName: "Ned",
            email: "ned@example.com",
            photoData: Data([0x01]),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let snapshot = try await store.syncedProfileSnapshot(ownerUserIdentifier: "user-1")
        #expect(snapshot?.displayName == "Ned")
        #expect(snapshot?.email == "ned@example.com")
        #expect(snapshot?.photoData == Data([0x01]))
        #expect(snapshot?.updatedAt == Date(timeIntervalSince1970: 100))
    }

    @Test("Upsert on an existing owner updates in place, not a second row")
    func upsertUpdatesInPlace() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await store.upsertSyncedProfile(
            ownerUserIdentifier: "user-1",
            displayName: "Ned",
            email: "ned@example.com",
            photoData: nil,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        try await store.upsertSyncedProfile(
            ownerUserIdentifier: "user-1",
            displayName: "Edward",
            email: "edward@example.com",
            photoData: Data([0x02]),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let snapshot = try await store.syncedProfileSnapshot(ownerUserIdentifier: "user-1")
        #expect(snapshot?.displayName == "Edward")
        #expect(snapshot?.email == "edward@example.com")
        #expect(snapshot?.photoData == Data([0x02]))
        #expect(snapshot?.updatedAt == Date(timeIntervalSince1970: 200))
    }

    @Test("Different owners never collide (per-user keying, DUT-371)")
    func differentOwnersDoNotCollide() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await store.upsertSyncedProfile(
            ownerUserIdentifier: "user-1",
            displayName: "Ned",
            email: "ned@example.com",
            photoData: nil
        )
        try await store.upsertSyncedProfile(
            ownerUserIdentifier: "user-2",
            displayName: "Spencer",
            email: "spencer@example.com",
            photoData: nil
        )
        let first = try await store.syncedProfileSnapshot(ownerUserIdentifier: "user-1")
        let second = try await store.syncedProfileSnapshot(ownerUserIdentifier: "user-2")
        #expect(first?.displayName == "Ned")
        #expect(second?.displayName == "Spencer")
    }

    @Test("No row for an owner reads back nil")
    func missingOwnerReadsNil() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        let snapshot = try await store.syncedProfileSnapshot(ownerUserIdentifier: "nobody")
        #expect(snapshot == nil)
    }

    @Test("A blank owner identifier is rejected, not written as a phantom row")
    func blankOwnerIsRejected() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await store.upsertSyncedProfile(
            ownerUserIdentifier: "   ",
            displayName: "Nobody",
            email: "nobody@example.com",
            photoData: nil
        )
        let snapshot = try await store.syncedProfileSnapshot(ownerUserIdentifier: "   ")
        #expect(snapshot == nil)
    }

    @Test("CloudKit-duplicate rows for the same owner collapse to the newest by updatedAt")
    func duplicateRowsCollapseToNewest() async throws {
        // Simulate what two offline devices writing the same owner can leave
        // behind: two rows for "user-1" inserted directly (bypassing the
        // upsert's own collapse), mirroring how CloudKit can deliver
        // duplicate CKRecords for a non-unique-constrained model (DUT-378's
        // rationale for SyncedSavedRecipe, same shape here).
        let container = try RecipeStore.inMemoryContainer()
        let context = ModelContext(container)
        context.insert(
            SyncedProfile(
                ownerUserIdentifier: "user-1",
                displayName: "Older",
                email: "older@example.com",
                updatedAt: Date(timeIntervalSince1970: 100)
            )
        )
        context.insert(
            SyncedProfile(
                ownerUserIdentifier: "user-1",
                displayName: "Newer",
                email: "newer@example.com",
                updatedAt: Date(timeIntervalSince1970: 200)
            )
        )
        try context.save()

        let store = RecipeStore(modelContainer: container)
        // Reading tolerates the duplicates and returns the newest.
        let snapshot = try await store.syncedProfileSnapshot(ownerUserIdentifier: "user-1")
        #expect(snapshot?.displayName == "Newer")

        // The next upsert collapses the duplicates down to one row.
        try await store.upsertSyncedProfile(
            ownerUserIdentifier: "user-1",
            displayName: "Newest",
            email: "newest@example.com",
            photoData: nil,
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        let rows = try context.fetch(
            FetchDescriptor<SyncedProfile>(
                predicate: #Predicate { $0.ownerUserIdentifier == "user-1" }
            )
        )
        #expect(rows.count == 1, "Upsert must collapse CloudKit-duplicate rows down to one")
        #expect(rows.first?.displayName == "Newest")
    }
}
