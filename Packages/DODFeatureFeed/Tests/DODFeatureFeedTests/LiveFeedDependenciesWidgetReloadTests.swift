import DODDomain
import DODNetworking
import DODPersistence
import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// DUT-561 — the featured "Latest" widget showed a gradient placeholder (not the
/// hero photo) for up to 4h after a new featured recipe because
/// `publishWidgetSnapshot` fired its widget reload BEFORE the detached hero
/// prefetch bridged the `.img` bytes to disk, and never fired a second reload.
/// The fix mirrors `SavedRecipesWidgetPublisher.publish`: await the prefetch,
/// then fire a SECOND `widgetReload?`. These tests assert the two-reload
/// behaviour via a reload-count spy and a fake prefetcher that signals
/// completion.
@Suite("LiveFeedDependencies second widget reload after hero prefetch (DUT-561)")
struct LiveFeedDependenciesSecondReloadTests {

    @Test("publishing a snapshot with un-bridged hero bytes fires a SECOND reload after prefetch")
    func firesSecondReloadAfterPrefetch() async throws {
        let reloads = ReloadSpy()
        let widgetReload: LiveFeedDependencies.WidgetReloadHook = { entries in
            reloads.record(entries)
        }
        // Fake prefetcher that only completes once the test releases the gate,
        // so we can prove the ordering: reload #1 lands immediately (the
        // synchronous line-269 reload), reload #2 lands strictly AFTER the
        // prefetch completes.
        let gate = PrefetchGate()
        let prefetcher: LiveFeedDependencies.ImagePrefetcher = { _ in
            await gate.waitUntilOpen()
        }

        let suiteName = "DUT-561.\(UUID().uuidString)"
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
            widgetReload: widgetReload,
            imagePrefetcher: prefetcher
        )

        let items = [
            RecipeListItem(
                id: 1,
                title: "Fresh Featured",
                excerpt: "",
                heroImage: URL(string: "https://example.com/hero.jpg"),
                publishedAt: Date(timeIntervalSince1970: 1),
                totalTimeDisplay: nil
            )
        ]

        await dependencies.publishWidgetSnapshot(items: items)

        // The first reload (line 269) is synchronous with publish; assert it
        // fired before the prefetch is allowed to complete — and that a second
        // reload has NOT yet landed (it's blocked behind the gated prefetch).
        #expect(reloads.count == 1)

        // Release the prefetch; the detached task should now fire reload #2.
        await gate.open()

        for _ in 0..<50 {
            if reloads.count == 2 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        // Two reloads total — matching the saved-recipes sibling's behaviour —
        // and the second carries the same entries so the freshly-bridged hero
        // appears without waiting for the 4-hour cadence.
        #expect(reloads.count == 2)
        let recorded = reloads.entriesLog
        #expect(recorded.count == 2)
        #expect(recorded.first?.first?.id == 1)
        #expect(recorded.last?.first?.id == 1)
    }
}

/// Reload-count spy for the `WidgetReloadHook`. The hook is `@Sendable` and can
/// fire from a detached task, so guard the mutable state behind a lock.
private final class ReloadSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var log: [[WidgetSnapshot.Entry]] = []

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return log.count
    }

    var entriesLog: [[WidgetSnapshot.Entry]] {
        lock.lock()
        defer { lock.unlock() }
        return log
    }

    func record(_ entries: [WidgetSnapshot.Entry]) {
        lock.lock()
        defer { lock.unlock() }
        log.append(entries)
    }
}

/// A one-shot gate the fake prefetcher awaits, so the test controls exactly
/// when the prefetch "completes" and thus when the second reload can fire.
private actor PrefetchGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }

    func waitUntilOpen() async {
        if isOpen { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}

/// DUT-567 — the `.recipes` widget mode fell back to `entries.first` when the
/// split scan left `latestRecipe` nil (legacy payload / no classifier). That
/// first entry can be an article, and the eyebrow was hardcoded to
/// "Latest Recipe" for `.recipes` mode, mislabeling the article. The fix keys
/// the eyebrow off the resolved entry's own `isArticle`. These helpers mirror
/// the widget-extension `LatestContent.entry(from:)` fallback and the fixed
/// `eyebrow(for:mode:)` (which live in the `Widget/` extension target, outside
/// this package) so the resolution + labeling contract is regression-covered
/// here against a real snapshot produced by `publishWidgetSnapshot`.
@Suite("Latest widget .recipes fallback never mislabels an article (DUT-567)")
struct LatestRecipesFallbackEyebrowTests {

    /// Mirrors `LatestContent.entry(from:)` `.recipes` branch:
    /// `latestRecipe ?? entries.first`.
    private func recipesModeEntry(from snapshot: WidgetSnapshot) -> WidgetSnapshot.Entry? {
        snapshot.latestRecipe ?? snapshot.entries.first
    }

    /// Mirrors the FIXED `eyebrow(for:mode:)` `.recipes` branch — keyed off the
    /// resolved entry's `isArticle`, not the mode.
    private func recipesModeEyebrow(for entry: WidgetSnapshot.Entry) -> String {
        entry.isArticle ? "Latest Article" : "Latest Recipe"
    }

    @Test(".recipes fallback with only an article present is not labeled \"Latest Recipe\"")
    func articleOnlyFallbackIsNotLabeledLatestRecipe() async throws {
        let suiteName = "DUT-567.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let widgetStore = WidgetSnapshotStore(defaults: defaults)
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)

        // Classifier flags the only item as an article, so the scan leaves
        // `latestRecipe` nil — exactly the state that triggers the `.recipes`
        // fallback to `entries.first` (an article).
        let classifier: LiveFeedDependencies.LatestKindClassifier = { _ in true }
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
                id: 42,
                title: "Only an Article",
                excerpt: "",
                heroImage: nil,
                publishedAt: Date(timeIntervalSince1970: 1),
                totalTimeDisplay: nil
            )
        ]

        await dependencies.publishWidgetSnapshot(items: items)

        let snapshot = try #require(widgetStore.read())
        // Precondition: the scan produced the fallback-triggering state.
        #expect(snapshot.latestRecipe == nil)
        let resolved = try #require(recipesModeEntry(from: snapshot))
        #expect(resolved.isArticle == true)

        // The defect: an article must never be labeled "Latest Recipe".
        let eyebrow = recipesModeEyebrow(for: resolved)
        #expect(eyebrow != "Latest Recipe")
        #expect(eyebrow == "Latest Article")
    }

    @Test(".recipes fallback with a real recipe is still labeled \"Latest Recipe\"")
    func recipeFallbackKeepsLatestRecipeLabel() async throws {
        let suiteName = "DUT-567.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let widgetStore = WidgetSnapshotStore(defaults: defaults)
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)

        // No classifier → degraded path sets `latestRecipe` to the top item
        // (non-article), so the eyebrow stays "Latest Recipe".
        let dependencies = LiveFeedDependencies(
            client: WPRestClient(),
            store: store,
            monitor: NetworkMonitor(),
            widgetStore: widgetStore
        )

        let items = [
            RecipeListItem(
                id: 7,
                title: "A Recipe",
                excerpt: "",
                heroImage: nil,
                publishedAt: Date(timeIntervalSince1970: 1),
                totalTimeDisplay: nil
            )
        ]

        await dependencies.publishWidgetSnapshot(items: items)

        let snapshot = try #require(widgetStore.read())
        let resolved = try #require(recipesModeEntry(from: snapshot))
        #expect(resolved.isArticle == false)
        #expect(recipesModeEyebrow(for: resolved) == "Latest Recipe")
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
