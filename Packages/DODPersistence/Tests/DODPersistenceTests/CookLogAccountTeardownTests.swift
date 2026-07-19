import DODSupport
import Foundation
import Testing

@testable import DODPersistence

/// Account-teardown completeness for the cook journal (SDET bug hunt). The
/// cook journal (`CachedCookLogEntry`) is local-only, device-private data —
/// never CloudKit-synced (see `SchemaV6`) — containing personal reflection
/// notes, ratings, and photos. Sign Out / Delete Profile never cleared it, so
/// User A's private cook history leaked forward to whoever signed into the
/// same shared device next (the exact class of leak the DUT-565 recent-search
/// + comment-moderation teardown clears already guard against, but missed
/// here). `deleteAllCookLogs()` closes that gap; these tests exercise it in
/// isolation from the view-layer wiring. Uses the default `CookPhotoStore()`
/// dir like `CookLogPhotoTeardownTests`, so it's `.serialized` too.
@Suite("Cook-log account teardown", .serialized) struct CookLogAccountTeardownTests {

    private static let cookedAt = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func deletingAllCookLogsClearsEntriesAndPhotos() async throws {
        let photoStore = CookPhotoStore()
        let fileID1 = try photoStore.save(Data([0x01, 0x02, 0x03]))
        let fileID2 = try photoStore.save(Data([0x04, 0x05, 0x06]))

        let store = try await makeStore()
        try await store.logCook(
            CookLogEntry(
                id: UUID(),
                recipeID: 10,
                recipeTitle: "Dutch Oven Chicken",
                cookedAt: Self.cookedAt,
                note: "Went great",
                personalRating: 5,
                photoLocalID: fileID1
            )
        )
        try await store.logCook(
            CookLogEntry(
                id: UUID(),
                recipeID: 11,
                recipeTitle: "Campfire Cobbler",
                cookedAt: Self.cookedAt.addingTimeInterval(60),
                note: "Too much sugar",
                personalRating: 3,
                photoLocalID: fileID2
            )
        )
        #expect(try await store.allCookLogs().count == 2)

        try await store.deleteAllCookLogs()

        #expect(try await store.allCookLogs().isEmpty)
        #expect(photoStore.data(forID: fileID1) == nil)
        #expect(photoStore.data(forID: fileID2) == nil)
    }

    @Test func deletingAllCookLogsOnAnAlreadyEmptyJournalDoesNotThrow() async throws {
        let store = try await makeStore()
        #expect(try await store.allCookLogs().isEmpty)

        try await store.deleteAllCookLogs()  // must not throw

        #expect(try await store.allCookLogs().isEmpty)
    }

    @Test func entryWithNoPhotoIsRemovedCleanly() async throws {
        let store = try await makeStore()
        try await store.logCook(
            CookLogEntry(
                id: UUID(),
                recipeID: 12,
                recipeTitle: "Sourdough Boule",
                cookedAt: Self.cookedAt,
                photoLocalID: nil
            )
        )
        #expect(try await store.allCookLogs().count == 1)

        try await store.deleteAllCookLogs()  // no photo to delete — must not crash

        #expect(try await store.allCookLogs().isEmpty)
    }
}
