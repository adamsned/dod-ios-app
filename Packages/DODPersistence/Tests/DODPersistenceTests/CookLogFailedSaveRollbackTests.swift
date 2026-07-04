import DODSupport
import Foundation
import Testing

@testable import DODPersistence

/// DUT-473 (SDET hunt round 10) — the DUT-208 inverse. `logCook` inserts a
/// `CachedCookLogEntry` then `save()`s. If that `save()` throws AFTER the
/// insert, the row lingers PENDING in the `@ModelActor`'s long-lived,
/// autosave-off context, so the NEXT successful `save()` from any other store
/// write commits it — a phantom cook whose `photoLocalID` points at a JPEG the
/// caller already deleted on the throw. The fix rolls the insert back and
/// deletes the just-written photo on a failed save, so a failed log leaves
/// neither a ghost row nor an orphaned file.
///
/// The failed `save()` is simulated via the DEBUG-only per-actor
/// `setCookLogSaveFailpointForTesting` hook (real disk-pressure failures aren't
/// reproducible in a unit test). The failpoint is per-store-instance, so these
/// tests don't need `.serialized` and can't bleed into other suites.
@Suite("Cook-log failed-save rollback (DUT-473)")
struct CookLogFailedSaveRollbackTests {

    private static let cookedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private struct SaveFailure: Error {}

    private func entry(id: UUID, recipeID: Int, photoLocalID: String?) -> CookLogEntry {
        CookLogEntry(
            id: id,
            recipeID: recipeID,
            recipeTitle: "Lasagna",
            cookedAt: Self.cookedAt,
            photoLocalID: photoLocalID
        )
    }

    /// A failed `save()` during `logCook` must NOT leave a pending row that a
    /// LATER successful store write commits, and must delete the just-written
    /// photo file so it doesn't orphan.
    @Test func failedSaveLeavesNoRowAndNoOrphanPhoto() async throws {
        let photoStore = CookPhotoStore()
        let fileID = try photoStore.save(Data([0xFF, 0xD8, 0xFF]))
        #expect(photoStore.data(forID: fileID) != nil)

        let store = try await makeStore()

        await store.setCookLogSaveFailpointForTesting(SaveFailure())

        await #expect(throws: SaveFailure.self) {
            try await store.logCook(entry(id: UUID(), recipeID: 1, photoLocalID: fileID))
        }

        // The photo the caller wrote must be gone, not orphaned.
        #expect(photoStore.data(forID: fileID) == nil)

        // Clear the failpoint and drive a LATER successful store write. Before
        // the fix, the pending failed insert rode along on this save.
        await store.setCookLogSaveFailpointForTesting(nil)
        try await store.logCook(entry(id: UUID(), recipeID: 2, photoLocalID: nil))

        // Only the second (successful) cook exists — the failed one left no ghost.
        let logs = try await store.allCookLogs()
        #expect(logs.count == 1)
        #expect(logs.first?.recipeID == 2)
    }

    /// A successful `logCook` after a failed one still works — the rollback
    /// leaves the context clean, not wedged.
    @Test func recoversAfterAFailedSave() async throws {
        let store = try await makeStore()

        await store.setCookLogSaveFailpointForTesting(SaveFailure())
        await #expect(throws: SaveFailure.self) {
            try await store.logCook(entry(id: UUID(), recipeID: 9, photoLocalID: nil))
        }
        await store.setCookLogSaveFailpointForTesting(nil)

        try await store.logCook(entry(id: UUID(), recipeID: 9, photoLocalID: nil))
        let logs = try await store.allCookLogs()
        #expect(logs.count == 1)
        #expect(logs.first?.recipeID == 9)
    }
}
