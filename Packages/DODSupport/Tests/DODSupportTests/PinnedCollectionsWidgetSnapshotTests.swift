import Foundation
import Testing

@testable import DODSupport

@Suite("PinnedCollectionsWidgetSnapshot") struct PinnedCollectionsWidgetSnapshotTests {

    private static func freshDefaults() throws -> UserDefaults {
        let name = "dod.widget.pinned.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private static func sample() -> PinnedCollectionsWidgetSnapshot {
        typealias Snap = PinnedCollectionsWidgetSnapshot
        return Snap(
            writtenAt: Date(timeIntervalSince1970: 1_700_000_000),
            collections: [
                Snap.Collection(
                    id: UUID(),
                    name: "Weeknight",
                    totalCount: 9,
                    recipes: [
                        Snap.Recipe(recipeID: 1, title: "Chili", heroImageFilename: "1.jpg"),
                        Snap.Recipe(recipeID: 2, title: "Soup", heroImageFilename: nil),
                    ]
                ),
                Snap.Collection(id: UUID(), name: "Empty", totalCount: 0, recipes: []),
            ]
        )
    }

    @Test func writeThenReadRoundTrips() throws {
        let store = WidgetSnapshotStore(defaults: try Self.freshDefaults())
        let snap = Self.sample()
        try store.writePinnedCollections(snap)
        #expect(store.readPinnedCollections() == snap)
    }

    @Test func readReturnsNilWhenSchemaVersionMismatches() throws {
        let store = WidgetSnapshotStore(defaults: try Self.freshDefaults())
        let base = Self.sample()
        let bad = PinnedCollectionsWidgetSnapshot(
            schemaVersion: PinnedCollectionsWidgetSnapshot.currentSchemaVersion + 1,
            writtenAt: base.writtenAt,
            collections: base.collections
        )
        try store.writePinnedCollections(bad)
        #expect(store.readPinnedCollections() == nil)
    }

    @Test func readReturnsNilWhenNothingWritten() throws {
        let store = WidgetSnapshotStore(defaults: try Self.freshDefaults())
        #expect(store.readPinnedCollections() == nil)
    }

    @Test func recipeDeepLinkIsNilForNonPositiveID() {
        typealias Rec = PinnedCollectionsWidgetSnapshot.Recipe
        #expect(Rec(recipeID: 0, title: "x", heroImageFilename: nil).deepLinkURL == nil)
        #expect(Rec(recipeID: -4, title: "x", heroImageFilename: nil).deepLinkURL == nil)
    }

    @Test func recipeDeepLinkIsDodRecipeURL() {
        let recipe = PinnedCollectionsWidgetSnapshot.Recipe(recipeID: 42, title: "x", heroImageFilename: nil)
        #expect(recipe.deepLinkURL?.absoluteString == "dod://recipe/42")
    }

    @Test func collectionLookupByIDFindsOrReturnsNil() {
        let snap = Self.sample()
        let first = snap.collections[0]
        #expect(snap.collection(id: first.id) == first)
        #expect(snap.collection(id: UUID()) == nil)
    }
}
