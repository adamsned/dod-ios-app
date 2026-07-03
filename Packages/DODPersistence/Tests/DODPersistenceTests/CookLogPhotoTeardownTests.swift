import DODSupport
import Foundation
import Testing

@testable import DODPersistence

/// DUT-338 (SDET 2026-06-28) — deleting, replacing, or clearing a cook-journal
/// entry's photo must remove the now-unreferenced file, not orphan it in
/// Application Support (which is never OS-purged). `delete(id:)` had zero
/// callers before this fix. Uses the default `CookPhotoStore()` dir — the same
/// one `RecipeStore`'s teardown writes to — with unique ids per test.
@Suite("Cook-log photo teardown (DUT-338)", .serialized) struct CookLogPhotoTeardownTests {

    private static let cookedAt = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func deletingAnEntryDeletesItsPhotoFile() async throws {
        let photoStore = CookPhotoStore()
        let fileID = try photoStore.save(Data([0xFF, 0xD8, 0xFF]))
        #expect(photoStore.data(forID: fileID) != nil)

        let store = try await makeStore()
        let id = UUID()
        try await store.logCook(
            CookLogEntry(
                id: id,
                recipeID: 1,
                recipeTitle: "Lasagna",
                cookedAt: Self.cookedAt,
                photoLocalID: fileID
            )
        )

        try await store.deleteCookLog(id: id)

        #expect(photoStore.data(forID: fileID) == nil)  // file gone, not orphaned
    }

    @Test func replacingAPhotoDeletesTheOldFileButKeepsTheNew() async throws {
        let photoStore = CookPhotoStore()
        let oldID = try photoStore.save(Data([0x01]))
        let newID = try photoStore.save(Data([0x02]))

        let store = try await makeStore()
        let id = UUID()
        try await store.logCook(
            CookLogEntry(
                id: id,
                recipeID: 2,
                recipeTitle: "Stew",
                cookedAt: Self.cookedAt,
                photoLocalID: oldID
            )
        )

        try await store.updateCookLog(
            CookLogEntry(
                id: id,
                recipeID: 2,
                recipeTitle: "Stew",
                cookedAt: Self.cookedAt,
                photoLocalID: newID
            )
        )

        #expect(photoStore.data(forID: oldID) == nil)  // old replaced file gone
        #expect(photoStore.data(forID: newID) != nil)  // new file kept
        photoStore.delete(id: newID)
    }

    @Test func clearingAPhotoDeletesTheFile() async throws {
        let photoStore = CookPhotoStore()
        let fileID = try photoStore.save(Data([0x03]))

        let store = try await makeStore()
        let id = UUID()
        try await store.logCook(
            CookLogEntry(
                id: id,
                recipeID: 3,
                recipeTitle: "Chili",
                cookedAt: Self.cookedAt,
                photoLocalID: fileID
            )
        )

        try await store.updateCookLog(
            CookLogEntry(
                id: id,
                recipeID: 3,
                recipeTitle: "Chili",
                cookedAt: Self.cookedAt,
                photoLocalID: nil
            )
        )

        #expect(photoStore.data(forID: fileID) == nil)
    }

    /// DUT-515 — the edit path writes the new JPEG to disk BEFORE calling
    /// `updateCookLog`. If the row was deleted out from under an open edit, the
    /// guard-miss must delete that just-written file so it doesn't orphan (no row
    /// will ever reference its `photoLocalID`).
    @Test func updatingANonExistentRowDeletesTheJustWrittenPhoto() async throws {
        let photoStore = CookPhotoStore()
        let fileID = try photoStore.save(Data([0x04]))
        #expect(photoStore.data(forID: fileID) != nil)

        let store = try await makeStore()
        // No row with this id was ever logged — the edit targets a deleted entry.
        try await store.updateCookLog(
            CookLogEntry(
                id: UUID(),
                recipeID: 4,
                recipeTitle: "Cornbread",
                cookedAt: Self.cookedAt,
                photoLocalID: fileID
            )
        )

        #expect(photoStore.data(forID: fileID) == nil)  // just-written file cleaned up, not orphaned
    }
}
