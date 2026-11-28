import DODDomain
import Foundation
import Testing

@testable import DODPersistence

/// Firestore doc mapping + merge rules for cross-platform saved sync. The field
/// maps here are what Android's `SavedRecipeDoc.kt` writes and reads.
@Suite("Saved recipe Firestore doc + remote merge")
struct SavedRecipeDocTests {

    /// Exactly what Android's `SavedRecipeEntity.toDoc()` writes (Firestore hands numbers back as Int64).
    private let androidFields: [String: Any] = [
        "id": Int64(42),
        "title": "Dutch Oven Lasagna",
        "excerpt": "Layers",
        "imageUrl": NSNull(),
        "canonicalUrl": "https://www.dutchovendaddy.com/lasagna/",
        "publishedDate": "2026-05-01T10:00:00",
        "totalTimeMinutes": Int64(90),
        "savedAtEpochMs": Int64(1_700_000_000_123),
        "kind": "ARTICLE",
    ]

    @Test("Reads an Android doc, and writes the same keys back")
    func androidRoundTrip() throws {
        let doc = try #require(SavedRecipeDoc(fields: androidFields))
        #expect(doc.id == 42)
        #expect(doc.imageURL == nil)
        #expect(doc.totalTimeMinutes == 90)
        #expect(doc.isArticle)
        #expect(doc.savedAt == Date(timeIntervalSince1970: 1_700_000_000.123))
        // Zone-less WordPress date reads as UTC.
        #expect(doc.publishedAt == Date(timeIntervalSince1970: 1_777_629_600))
        #expect(Set(doc.fields.keys) == Set(androidFields.keys))
        #expect(doc.fields["kind"] as? String == "ARTICLE")
        #expect(SavedRecipeDoc(fields: doc.fields) == doc)
    }

    @Test("Malformed docs are skipped; unknown kind is a recipe")
    func malformed() {
        var missingID = androidFields
        missingID["id"] = nil
        #expect(SavedRecipeDoc(fields: missingID) == nil)
        var badTitle = androidFields
        badTitle["title"] = 7
        #expect(SavedRecipeDoc(fields: badTitle) == nil)
        var video = androidFields
        video["kind"] = "VIDEO"
        #expect(SavedRecipeDoc(fields: video)?.isArticle == false)
    }

    @Test("Local save and unsave reach the mirror; remote changes don't echo back")
    func mirrorAndRemoteMerge() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        let mirror = RecordingMirror()
        await store.setSavedMirror(mirror)
        try await store.cache(listItem: listItem(id: 1))

        _ = try await store.toggleSaved(id: 1)
        _ = try await store.toggleSaved(id: 1)
        #expect(mirror.events == ["saved 1", "removed 1"])

        // A save from Android lands with its own savedAt and doesn't echo.
        let remote = try #require(SavedRecipeDoc(fields: androidFields))
        try await store.applyRemoteSaved(remote)
        #expect(try await store.isSaved(id: 42))
        var expected = remote
        expected.publishedDate = "2026-05-01T10:00:00Z"  // iOS writes the zone; Android reads the date part
        #expect(try await store.savedRecipeDocs() == [expected])

        // A later remote update keeps this device's savedAt.
        var renamed = remote
        renamed.title = "Lasagna"
        renamed.savedAtEpochMs = 1
        try await store.applyRemoteSaved(renamed)
        #expect(try await store.savedRecipeDocs().first?.savedAtEpochMs == remote.savedAtEpochMs)
        #expect(try await store.savedRecipeDocs().first?.title == "Lasagna")

        // A remote removal wins over a local save and clears the local pin.
        _ = try await store.toggleSaved(id: 1)
        try await store.applyRemoteRemoval(id: 1)
        #expect(try await store.isSaved(id: 1) == false)
        #expect(try await store.localIsSavedPinForTesting(id: 1) == false)
        #expect(mirror.events == ["saved 1", "removed 1", "saved 1"])
    }

    private func listItem(id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Chili",
            excerpt: "Hearty.",
            heroImage: URL(string: "https://dutchovendaddy.com/\(id).jpg"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil,
            canonicalURL: URL(string: "https://dutchovendaddy.com/\(id)") ?? URL(filePath: "/")
        )
    }
}

private final class RecordingMirror: SavedRecipeMirror, @unchecked Sendable {
    private let lock = NSLock()
    private var log: [String] = []
    var events: [String] { lock.withLock { log } }
    func saved(_ doc: SavedRecipeDoc) { lock.withLock { log.append("saved \(doc.id)") } }
    func removed(id: Int) { lock.withLock { log.append("removed \(id)") } }
}
