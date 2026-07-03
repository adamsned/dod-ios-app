import DODDomain
import DODNetworking
import DODPersistence
import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// Regression net for REG-T-360 / CL-45.
///
/// T-360 wired `WidgetImageBridge.writeImage` into `RecipeStore.cacheImage`,
/// but no production caller asked the feed-load path to push hero-image
/// bytes through `cacheImage` — only the saved-recipe pre-download path
/// (`LiveSavedDependencies.preDownloadImages`, AC-5.2) did. Result: the
/// widget snapshot stored deterministic filenames pointing at files that
/// never existed, and the widget always rendered the gradient placeholder.
///
/// T-362's fix routes feed hero URLs through an `ImagePrefetcher` closure
/// that the App composition root constructs from the `ImageLoader` +
/// `RecipeStore` singletons. This test asserts the call site fires — the
/// production paths it routes to (`ImageLoader.data(for:)`,
/// `RecipeStore.cacheImage(url:bytes:)`, `WidgetImageBridge.writeImage`)
/// are already covered by their own existing test suites
/// (`ImageLoaderTests`, `RecipeStoreTests`, `WidgetImageBridgeTests`).
@Suite("LiveFeedDependencies image bridge prefetch (REG-T-360 / T-362)")
struct LiveFeedDependenciesImageBridgeTests {

    @Test("publishWidgetSnapshot invokes the image prefetcher with the snapshotted hero URLs")
    func publishWidgetSnapshotKicksOffPrefetch() async throws {
        // Counting stub — captures the URL set the snapshot writer
        // hands off so the test can assert the right URLs are
        // routed through.
        let captured = CapturedURLs()
        let prefetcher: LiveFeedDependencies.ImagePrefetcher = { urls in
            await captured.append(urls)
        }
        // A throwaway UserDefaults suite so the test doesn't pollute the
        // shared App Group store. The snapshot write succeeds and the
        // prefetch hook fires immediately after.
        let suiteName = "REG-T-360.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let widgetStore = WidgetSnapshotStore(defaults: defaults)
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        let dependencies = LiveFeedDependencies(
            client: WPRestClient(),
            store: store,
            monitor: NetworkMonitor(),
            widgetStore: widgetStore,
            widgetReload: nil,
            imagePrefetcher: prefetcher
        )

        let items = [
            RecipeListItem(
                id: 1,
                title: "First",
                excerpt: "",
                heroImage: URL(string: "https://example.com/first.jpg"),
                publishedAt: Date(timeIntervalSince1970: 1),
                totalTimeDisplay: nil
            ),
            RecipeListItem(
                id: 2,
                title: "Second",
                excerpt: "",
                heroImage: URL(string: "https://example.com/second.jpg"),
                publishedAt: Date(timeIntervalSince1970: 2),
                totalTimeDisplay: nil
            ),
        ]

        await dependencies.publishWidgetSnapshot(items: items)

        // The prefetch fires inside a `Task.detached`. Poll a few times
        // with a short yield between checks rather than a fixed sleep,
        // so the test stays fast on real machines while still tolerating
        // CI scheduler jitter.
        for _ in 0..<50 {
            if await captured.count == 2 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let recorded = await captured.urls
        let firstURL = try #require(URL(string: "https://example.com/first.jpg"))
        let secondURL = try #require(URL(string: "https://example.com/second.jpg"))
        #expect(recorded.count == 2)
        #expect(recorded.contains(firstURL))
        #expect(recorded.contains(secondURL))
    }
}

private actor CapturedURLs {
    private(set) var urls: [URL] = []

    var count: Int { urls.count }

    func append(_ batch: [URL]) {
        urls.append(contentsOf: batch)
    }
}

/// DUT-485 / T-905 — the bounded classification scan populates the snapshot's
/// `latestRecipe` / `latestArticle` for the user-configurable "Latest" widget.
@Suite("LiveFeedDependencies latest recipe/article scan (DUT-485 / T-905)")
struct LiveFeedDependenciesLatestScanTests {

    @Test("scan records the newest recipe and newest article, and the top eyebrow flag")
    func scanFindsBothKinds() async throws {
        let suiteName = "DUT-485.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let widgetStore = WidgetSnapshotStore(defaults: defaults)
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)

        // Top post (id 1) is an article; id 2 is a recipe. The classifier
        // returns true (article) only for id 1.
        let classifier: LiveFeedDependencies.LatestKindClassifier = { item in item.id == 1 }
        let dependencies = LiveFeedDependencies(
            client: WPRestClient(),
            store: store,
            monitor: NetworkMonitor(),
            widgetStore: widgetStore,
            widgetReload: nil,
            imagePrefetcher: nil,
            latestKindClassifier: classifier
        )

        let items = [
            RecipeListItem(
                id: 1,
                title: "An Article",
                excerpt: "",
                heroImage: nil,
                publishedAt: Date(timeIntervalSince1970: 2),
                totalTimeDisplay: nil
            ),
            RecipeListItem(
                id: 2,
                title: "A Recipe",
                excerpt: "",
                heroImage: nil,
                publishedAt: Date(timeIntervalSince1970: 1),
                totalTimeDisplay: nil
            ),
        ]

        await dependencies.publishWidgetSnapshot(items: items)

        let snapshot = try #require(widgetStore.read())
        // Top post is an article → Auto eyebrow flag on entry 0.
        #expect(snapshot.entries.first?.isArticle == true)
        #expect(snapshot.latestArticle?.id == 1)
        #expect(snapshot.latestArticle?.isArticle == true)
        #expect(snapshot.latestRecipe?.id == 2)
        #expect(snapshot.latestRecipe?.isArticle == false)
    }

    @Test("no classifier wired → latestRecipe is the top item, no article (degraded path)")
    func scanWithoutClassifierMatchesLegacy() async throws {
        let suiteName = "DUT-485.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let widgetStore = WidgetSnapshotStore(defaults: defaults)
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        let dependencies = LiveFeedDependencies(
            client: WPRestClient(),
            store: store,
            monitor: NetworkMonitor(),
            widgetStore: widgetStore
        )

        let items = [
            RecipeListItem(
                id: 5,
                title: "Top",
                excerpt: "",
                heroImage: nil,
                publishedAt: Date(timeIntervalSince1970: 1),
                totalTimeDisplay: nil
            )
        ]

        await dependencies.publishWidgetSnapshot(items: items)

        let snapshot = try #require(widgetStore.read())
        #expect(snapshot.entries.first?.isArticle == false)
        #expect(snapshot.latestRecipe?.id == 5)
        #expect(snapshot.latestArticle == nil)
    }
}
