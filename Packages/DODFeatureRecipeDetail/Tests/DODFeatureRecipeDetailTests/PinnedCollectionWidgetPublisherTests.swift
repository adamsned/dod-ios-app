import DODDomain
import DODPersistence
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("PinnedCollectionWidgetPublisher (DUT-172)") struct PinnedCollectionWidgetPublisherTests {

    @Test func publishWritesCollectionWithItsRecipes() async throws {
        let harness = try await Harness.make()
        try await harness.saveRecipe(id: 1, title: "First")
        try await harness.saveRecipe(id: 2, title: "Second")
        let collection = try await harness.makeCollection(name: "Weeknight", recipeIDs: [1, 2])
        await harness.publisher.publish()
        let snapshot = try #require(harness.widgetStore.readPinnedCollections())
        #expect(snapshot.collections.count == 1)
        guard let out = snapshot.collections.first else {
            Issue.record("Expected a collection in the snapshot")
            return
        }
        #expect(out.recipes.map(\.recipeID) == [1, 2])
        #expect(out.name == "Weeknight")
        #expect(out.totalCount == 2)
    }

    @Test func publishCapsRecipesAtSix() async throws {
        let harness = try await Harness.make()
        // Save recipes 1 through 8
        for index in 1...8 {
            try await harness.saveRecipe(id: index, title: "R\(index)")
        }
        // Put them all in one collection
        let collection = try await harness.makeCollection(name: "Test", recipeIDs: Array(1...8))
        await harness.publisher.publish()
        let snapshot = try #require(harness.widgetStore.readPinnedCollections())
        #expect(snapshot.collections.count == 1)
        guard let out = snapshot.collections.first else {
            Issue.record("Expected a collection in the snapshot")
            return
        }
        #expect(out.recipes.count == PinnedCollectionsWidgetSnapshotConfig.maxRecipesPerCollection)
        #expect(out.totalCount == 8)
    }

    @Test func publishWritesEmptyCollectionWithZeroCount() async throws {
        let harness = try await Harness.make()
        // Create a collection with no recipes
        let collection = try await harness.makeCollection(name: "Empty", recipeIDs: [])
        await harness.publisher.publish()
        let snapshot = try #require(harness.widgetStore.readPinnedCollections())
        #expect(snapshot.collections.count == 1)
        guard let out = snapshot.collections.first else {
            Issue.record("Expected a collection in the snapshot")
            return
        }
        #expect(out.recipes.isEmpty)
        #expect(out.totalCount == 0)
    }

    @Test func publishInvokesReloadHook() async throws {
        let harness = try await Harness.make()
        try await harness.saveRecipe(id: 1, title: "First")
        let collection = try await harness.makeCollection(name: "Test", recipeIDs: [1])
        await harness.publisher.publish()
        #expect(harness.reloadCount.value == 1)
    }

    // MARK: - Helpers

    /// Self-contained wiring for one test: an in-memory `RecipeStore`, a
    /// `WidgetSnapshotStore` backed by an isolated `UserDefaults` suite, a
    /// publisher that ties them together, and a counter for the reload
    /// hook calls.
    struct Harness: Sendable {
        let store: RecipeStore
        let widgetStore: WidgetSnapshotStore
        let publisher: PinnedCollectionWidgetPublisher
        let reloadCount: ReloadCounter

        static func make() async throws -> Harness {
            let container = try RecipeStore.inMemoryContainer()
            let store = RecipeStore(modelContainer: container)
            // Use a per-test UserDefaults suite so the snapshot bytes
            // don't bleed between tests. The harness is the only writer
            // for the duration of the test.
            let suiteName = "test.pinnedCollectionPublisher.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defaults.removePersistentDomain(forName: suiteName)
            let widgetStore = WidgetSnapshotStore(defaults: defaults)
            let reloadCount = ReloadCounter()
            let publisher = PinnedCollectionWidgetPublisher(
                store: store,
                widgetStore: widgetStore,
                reload: { reloadCount.increment() }
            )
            return Harness(
                store: store,
                widgetStore: widgetStore,
                publisher: publisher,
                reloadCount: reloadCount
            )
        }

        /// Cache + save a recipe. Sleeps a millisecond after the toggle
        /// so consecutive calls produce observably distinct
        /// `lastViewedAt` stamps — `RecipeStore.cache(listItem:)` always
        /// uses `.now`, and ordering assertions need monotonic timestamps.
        func saveRecipe(id: Int, title: String) async throws {
            let listItem = RecipeListItem(
                id: id,
                title: title,
                excerpt: "Excerpt.",
                heroImage: nil,
                publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
                totalTimeDisplay: nil,
                canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/")
            )
            try await store.cache(listItem: listItem)
            _ = try await store.toggleSaved(id: id)
            try await Task.sleep(nanoseconds: 1_000_000)
        }

        func makeCollection(name: String, recipeIDs: [Int]) async throws -> RecipeCollection {
            let collection = try await store.createCollection(name: name)
            for id in recipeIDs {
                // Add one at a time so collection order == recipeIDs order.
                let existing = try await store.collectionIDs(forRecipe: id)
                try await store.setCollections(forRecipe: id, to: existing.union([collection.id]))
            }
            return collection
        }
    }

    /// Thread-safe call counter for the reload hook so tests don't race
    /// against `await publisher.publish()`.
    final class ReloadCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return count
        }

        func increment() {
            lock.lock()
            defer { lock.unlock() }
            count += 1
        }
    }
}
