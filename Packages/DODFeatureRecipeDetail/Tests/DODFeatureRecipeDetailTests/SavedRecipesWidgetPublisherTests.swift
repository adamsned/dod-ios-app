import DODDomain
import DODPersistence
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// Spec trace: US-17 / AC-17.3 (host-side payload construction) +
/// AC-17.6 (host-forced reload).
///
/// Pinned by T-322 (SavedStore observation + snapshot writer wiring).
/// Mirrors the featured-widget publish path inside
/// `LiveFeedDependencies.publishWidgetSnapshot(items:)` — read from the
/// store, write the snapshot, fire the reload hook. These tests drive the
/// equivalent for the saved-recipes widget.
@Suite("SavedRecipesWidgetPublisher (T-322)") struct SavedRecipesWidgetPublisherTests {

    @Test func writerInvokedOnSave() async throws {
        let harness = try await Harness.make()
        try await harness.saveRecipe(id: 1, title: "Bread")
        await harness.publisher.publish()
        let snapshot = try #require(harness.widgetStore.readSavedRecipes())
        #expect(snapshot.entries.count == 1)
        #expect(snapshot.entries.first?.recipeID == 1)
        #expect(harness.reloadCount.value == 1, "Reload hook must fire after a save")
    }

    @Test func writerInvokedOnUnsave() async throws {
        let harness = try await Harness.make()
        try await harness.saveRecipe(id: 1, title: "Bread")
        await harness.publisher.publish()
        // Now unsave and republish.
        _ = try await harness.store.toggleSaved(id: 1)
        await harness.publisher.publish()
        let snapshot = try #require(
            harness.widgetStore.readSavedRecipes(),
            "Empty-state path still writes a snapshot (empty entries)"
        )
        #expect(snapshot.entries.isEmpty)
        #expect(harness.reloadCount.value == 2, "Both publish calls trigger a reload")
    }

    @Test func payloadIsMostRecentlySavedFirst() async throws {
        let harness = try await Harness.make()
        // Save id 1 first, then 2, then 3 — the publisher must return
        // them in [3, 2, 1] order (newest savedAt first per AC-17.3).
        // `saveRecipe(...)` sleeps between inserts so each `lastViewedAt`
        // stamp is observably distinct.
        try await harness.saveRecipe(id: 1, title: "First")
        try await harness.saveRecipe(id: 2, title: "Second")
        try await harness.saveRecipe(id: 3, title: "Third")
        await harness.publisher.publish()
        let snapshot = try #require(harness.widgetStore.readSavedRecipes())
        #expect(snapshot.entries.map(\.recipeID) == [3, 2, 1])
    }

    @Test func capsAtMaxEntriesWhenMoreAreSaved() async throws {
        let harness = try await Harness.make()
        // Save more than the cap so the trim is observable. T-768 / CL-165:
        // the cap is `SavedRecipesWidgetSnapshotConfig.maxEntries` (5 — the
        // large-widget size; small/medium take `prefix(1)`/`prefix(3)`).
        for index in 1...7 {
            try await harness.saveRecipe(id: index, title: "R\(index)")
        }
        await harness.publisher.publish()
        let snapshot = try #require(harness.widgetStore.readSavedRecipes())
        #expect(snapshot.entries.count == SavedRecipesWidgetSnapshotConfig.maxEntries)
        #expect(snapshot.entries.map(\.recipeID) == [7, 6, 5, 4, 3], "Top-N by savedAt desc")
    }

    @Test func emptyPayloadOnFullClear() async throws {
        let harness = try await Harness.make()
        try await harness.saveRecipe(id: 1, title: "X")
        try await harness.saveRecipe(id: 2, title: "Y")
        // Clear everything by toggling both off.
        _ = try await harness.store.toggleSaved(id: 1)
        _ = try await harness.store.toggleSaved(id: 2)
        await harness.publisher.publish()
        let snapshot = try #require(harness.widgetStore.readSavedRecipes())
        #expect(snapshot.entries.isEmpty)
        #expect(harness.reloadCount.value == 1)
    }

    @Test func heroImageFilenameIsNilWhenBytesAreNotCached() async throws {
        // T-766 / CL-163 (DUT-72): the filename stays nil when the recipe's
        // hero bytes aren't cached (no bridged file to point at) — the widget
        // renders its gradient placeholder per AC-17.5 / AC-21.3.
        let harness = try await Harness.make()
        try await harness.saveRecipe(id: 1, title: "NoImage")
        await harness.publisher.publish()
        let snapshot = try #require(harness.widgetStore.readSavedRecipes())
        #expect(snapshot.entries.first?.heroImageFilename == nil)
    }

    @Test func heroImageFilenameIsSetWhenBytesAreCached() async throws {
        // T-766 / CL-163 (DUT-72): once the hero bytes are cached
        // (`RecipeStore.cacheImage`, which also mirrors them to the App Group
        // bridge per AC-21.2), the saved snapshot carries the deterministic
        // bridged filename so the widget renders the full-color photo — the
        // same path the Featured widget already uses.
        let harness = try await Harness.make()
        let heroURL = try #require(URL(string: "https://www.dutchovendaddy.com/img/1.jpg"))
        try await harness.saveRecipeWithCachedImage(id: 1, title: "Chili", heroURL: heroURL)
        await harness.publisher.publish()
        let snapshot = try #require(harness.widgetStore.readSavedRecipes())
        #expect(
            snapshot.entries.first?.heroImageFilename == WidgetImageBridge.filename(for: heroURL)
        )
    }

    @Test func emptyStoreStillProducesAReloadAndAnEmptyPayload() async throws {
        // No recipes ever saved — the publisher still writes an empty
        // payload and fires the reload hook. This is the path the host
        // would walk if the user uninstalls and reinstalls the widget
        // with no saves yet: the widget reads the empty snapshot and
        // renders its placeholder (AC-17.5).
        let harness = try await Harness.make()
        await harness.publisher.publish()
        let snapshot = try #require(harness.widgetStore.readSavedRecipes())
        #expect(snapshot.entries.isEmpty)
        #expect(harness.reloadCount.value == 1, "Reload fires even for the empty-state write")
    }

    @Test func nilReloadHookIsToleratedSilently() async throws {
        // If the host doesn't supply a reload closure (e.g. running
        // without the WidgetKit framework available, like a unit-test
        // wiring that doesn't care about widgets), `publish()` must not
        // crash — the write still happens, the call returns cleanly.
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        let suiteName = "test.savedWidgetPublisher.nilHook.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let widgetStore = WidgetSnapshotStore(defaults: defaults)
        let publisher = SavedRecipesWidgetPublisher(
            store: store,
            widgetStore: widgetStore,
            reload: nil
        )
        await publisher.publish()
        let snapshot = try #require(widgetStore.readSavedRecipes())
        #expect(snapshot.entries.isEmpty)
    }

    // MARK: - Helpers

    /// Self-contained wiring for one test: an in-memory `RecipeStore`, a
    /// `WidgetSnapshotStore` backed by an isolated `UserDefaults` suite, a
    /// publisher that ties them together, and a counter for the reload
    /// hook calls.
    struct Harness: Sendable {
        let store: RecipeStore
        let widgetStore: WidgetSnapshotStore
        let publisher: SavedRecipesWidgetPublisher
        let reloadCount: ReloadCounter

        static func make() async throws -> Harness {
            let container = try RecipeStore.inMemoryContainer()
            let store = RecipeStore(modelContainer: container)
            // Use a per-test UserDefaults suite so the snapshot bytes
            // don't bleed between tests. The harness is the only writer
            // for the duration of the test.
            let suiteName = "test.savedWidgetPublisher.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defaults.removePersistentDomain(forName: suiteName)
            let widgetStore = WidgetSnapshotStore(defaults: defaults)
            let reloadCount = ReloadCounter()
            let publisher = SavedRecipesWidgetPublisher(
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

        /// Like `saveRecipe` but with a hero image URL whose bytes are cached
        /// via `RecipeStore.cacheImage` — so `heroImageCached` is true and the
        /// publisher emits the bridged filename. T-766 / CL-163.
        func saveRecipeWithCachedImage(id: Int, title: String, heroURL: URL) async throws {
            let listItem = RecipeListItem(
                id: id,
                title: title,
                excerpt: "Excerpt.",
                heroImage: heroURL,
                publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
                totalTimeDisplay: nil,
                canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/")
            )
            try await store.cache(listItem: listItem)
            try await store.cacheImage(url: heroURL, bytes: Data([0xFF, 0xD8, 0xFF]))
            _ = try await store.toggleSaved(id: id)
            try await Task.sleep(nanoseconds: 1_000_000)
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
