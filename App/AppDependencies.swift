import DODAnalytics
import DODFeatureCategories
import DODFeatureFeed
import DODFeatureRecipeDetail
import DODFeatureSaved
import DODFeatureSearch
import DODNetworking
import DODPersistence
import DODSupport
import Foundation
import SwiftData
import SwiftUI
import WidgetKit

/// Composition root. Constructs every long-lived service once and hands
/// per-feature `…Dependencies` views to view models on demand.
///
/// Singletons by design: `WPRestClient`, `RecipePageFetcher`, `ImageLoader`,
/// `NetworkMonitor.shared`, `RecipeStore`, `Telemetry.shared`. All process-
/// wide infrastructure; constitution carveout applies.
@MainActor
final class AppDependencies {

    let store: RecipeStore
    let modelContainer: ModelContainer

    private let restClient: WPRestClient
    private let pageFetcher: RecipePageFetcher
    private let imageLoader: ImageLoader
    private let networkMonitor: NetworkMonitor
    private let commentsClient: WPCommentsClient
    private let ratingsClient: WPRMRatingsClient
    private let guestIdentityStore: any GuestIdentityStoring

    init() {
        do {
            self.modelContainer = try RecipeStore.productionContainer()
        } catch {
            // Schema migration failure must surface to the user (MIGRATION.md
            // discipline rule 4). For v1 we crash early so the issue is
            // unambiguous in TestFlight feedback.
            fatalError("SwiftData migration failed: \(error)")
        }
        self.store = RecipeStore(modelContainer: modelContainer)
        self.restClient = WPRestClient()
        self.pageFetcher = RecipePageFetcher()
        self.imageLoader = ImageLoader()
        self.networkMonitor = NetworkMonitor.shared
        // US-13/14/15 integration: the comments + ratings + guest-identity
        // clients are constructed alongside the rest of the long-lived
        // services and handed to `LiveRecipeDetailDependencies` on demand.
        self.commentsClient = WPCommentsClient()
        self.ratingsClient = WPRMRatingsClient()
        self.guestIdentityStore = KeychainGuestIdentityStore()
    }

    /// Called once from `@main` at app launch.
    func bootstrap() async {
        await networkMonitor.start()
        // TelemetryDeck app ID lives in DODApp.xcconfig (gitignored per
        // constitution §9). For v1 we read from Info.plist; if unset we
        // skip telemetry rather than fail launch.
        let appID = Bundle.main.object(forInfoDictionaryKey: "TelemetryDeckAppID") as? String
        if let appID, !appID.isEmpty {
            Telemetry.shared.start(appID: appID)
        }
        Telemetry.shared.send(.appOpen)
        // US-10: hand the store to the AppIntents environment so the entity
        // query and Spotlight indexer can read saved + recently-viewed rows.
        AppIntentEnvironment.register(store: store)
    }

    // MARK: - Per-feature dependency views

    func feedDependencies() -> some FeedDependencies {
        // After the feed writes a fresh snapshot into the App Group, ask
        // WidgetKit to rebuild any installed widget timelines so the user
        // sees the new featured recipe without waiting for our 4-hour
        // refresh cadence (spec.md US-9 AC-9.3).
        let reload: LiveFeedDependencies.WidgetReloadHook = { _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        // Fixes REG-T-360 / CL-45. The widget snapshot's
        // `heroImageFilename` strings are deterministic SHA256-of-URL,
        // but the bridge files only exist after `RecipeStore.cacheImage`
        // writes them. T-360 wired the cache-side hook but no production
        // call site asked for feed hero bytes — only saved-recipe
        // pre-download (AC-5.2). This prefetcher closes that gap by
        // routing the snapshotted hero URLs through the same
        // `ImageLoader` + `cacheImage` path. Fire-and-forget inside
        // `LiveFeedDependencies.publishWidgetSnapshot(items:)`.
        let loader = imageLoader
        let cacheStore = store
        let prefetch: LiveFeedDependencies.ImagePrefetcher = { urls in
            for url in urls {
                guard let bytes = try? await loader.data(for: url) else { continue }
                try? await cacheStore.cacheImage(url: url, bytes: bytes)
            }
        }
        return LiveFeedDependencies(
            client: restClient,
            store: store,
            monitor: networkMonitor,
            widgetReload: reload,
            imagePrefetcher: prefetch
        )
    }

    func categoriesDependencies() -> some CategoriesDependencies {
        LiveCategoriesDependencies(client: restClient, store: store)
    }

    func searchDependencies() -> some SearchDependencies {
        LiveSearchDependencies(client: restClient, store: store, monitor: networkMonitor)
    }

    func recipeDetailDependencies() -> some RecipeDetailDependencies {
        // After a save / unsave the recipe-detail view model asks the
        // dependency to refresh the saved-recipes widget snapshot. The
        // publisher writes to the App Group container and then calls this
        // hook, which is what actually pokes WidgetKit. The kind string
        // is pinned in spec.md AC-17.6 — must match the widget's
        // `kind` (T-321 will register it).
        let savedWidgetReload: SavedRecipesWidgetPublisher.ReloadHook = {
            WidgetCenter.shared.reloadTimelines(ofKind: "SavedRecipesWidget")
        }
        return LiveRecipeDetailDependencies(
            client: restClient,
            fetcher: pageFetcher,
            store: store,
            monitor: networkMonitor,
            commentsClient: commentsClient,
            ratingsClient: ratingsClient,
            guestIdentity: guestIdentityStore,
            savedWidgetPublisher: SavedRecipesWidgetPublisher(
                store: store,
                reload: savedWidgetReload
            )
        )
    }

    func savedDependencies() -> some SavedDependencies {
        LiveSavedDependencies(store: store, imageLoader: imageLoader)
    }
}
