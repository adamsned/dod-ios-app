import CloudKit
import DODAnalytics
import DODDomain
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
    private(set) var modelContainer: ModelContainer

    /// On-device local-notification service (US-42 / T-631). Long-lived —
    /// owns the authorization request the Settings toggle drives and the
    /// scheduling the (DEBUG) test affordance fires. No APNs / no server.
    let notificationService: NotificationService

    private let restClient: WPRestClient
    private let pageFetcher: RecipePageFetcher
    private let imageLoader: ImageLoader
    private let networkMonitor: NetworkMonitor
    private let commentsClient: WPCommentsClient
    private let ratingsClient: WPRMRatingsClient
    private let guestIdentityStore: any GuestIdentityStoring

    /// Diagnostic observer for the SwiftData ↔ CloudKit mirror (round-12
    /// backlog bug — "CloudKit recipe sync doesn't work"). Started from
    /// `bootstrap()` only when the iCloud-Sync opt-in is on.
    private let cloudKitDiagnostics = CloudKitSyncDiagnostics()

    init() {
        do {
            // L3 isolation hook: `-DODUseInMemoryStore` gives each UI-test
            // launch a clean, empty SwiftData store so saved recipes don't
            // persist across runs on a shared CI simulator (the cause of the
            // flaky "No saved recipes yet" empty-state assertions). Never set
            // in production — the app always uses the on-disk container.
            if ProcessInfo.processInfo.arguments.contains("-DODUseInMemoryStore") {
                self.modelContainer = try RecipeStore.inMemoryContainer()
            } else {
                self.modelContainer = try RecipeStore.productionContainer()
            }
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
        self.notificationService = NotificationService()
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
        // US-41 / AC-41.1 (T-702): conditional CloudKit availability
        // check. Only fires when the user has opted into iCloud sync via
        // T-703's Settings toggle or T-704's first-launch sheet —
        // otherwise the app never touches `CKContainer` at all, which is
        // the AC-41.1 graceful-fallback contract that keeps the existing
        // v1.0 behavior intact under no-iCloud-account + sync-declined
        // states.
        if UserDefaults.standard.bool(forKey: RecipeStore.cloudKitSyncOptInKey) {
            // Round-12 backlog bug: log every CloudKit mirror event so an
            // on-device run reveals which layer fails (schema / account /
            // never-enabled). Pairs with the account-status probe below.
            cloudKitDiagnostics.start()
            await checkCloudKitAvailability()
        }
    }

    /// US-41 / AC-41.1 + AC-41.7 / REG-25 + REG-26 (T-702). Probe the
    /// user's iCloud account status so subsequent sync attempts know
    /// whether to proceed (`.available`) or pause with a status sublabel
    /// (`.noAccount` / `.restricted` / `.couldNotDetermine` — T-705 owns
    /// the sublabel surface). Per AC-41.1 the app **must not crash** when
    /// the account is unavailable — we log + continue, and the existing
    /// SwiftData store keeps working unchanged on the AC-41.1 fallback
    /// path.
    ///
    /// Surface trace (REG-25): the only `CKContainer` APIs this method
    /// touches are the initializer + `accountStatus()`. No
    /// `publicCloudDatabase` / `sharedCloudDatabase` / `discoverUserIdentity`
    /// surface reference exists in the entire app per the REG-25 contract.
    private func checkCloudKitAvailability() async {
        let container = CKContainer(
            identifier: RecipeStore.cloudKitContainerIdentifier
        )
        do {
            let status = try await container.accountStatus()
            DODLog.app.info(
                "CloudKit account status: \(String(describing: status))"
            )
        } catch {
            DODLog.app.notice(
                "CloudKit availability check failed: \(error.localizedDescription)"
            )
        }
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
            imageLoader: imageLoader,
            savedWidgetPublisher: SavedRecipesWidgetPublisher(
                store: store,
                reload: savedWidgetReload
            )
        )
    }

    func savedDependencies() -> some SavedDependencies {
        LiveSavedDependencies(store: store, imageLoader: imageLoader)
    }

    /// US-41 / AC-41.3 (T-703). Build the Settings dependency surface
    /// for the iCloud Sync toggle. The returned value drives the
    /// flag-write → container-rebuild handshake the view-model needs:
    ///
    ///   1. write `RecipeStore.cloudKitSyncOptInKey` to UserDefaults
    ///      (the value `RecipeStore.makeProductionConfiguration()` reads),
    ///   2. call `RecipeStore.recreateContainerAfterOptInChange()` so the
    ///      stale `ModelContainer` is discarded and a fresh one is built
    ///      against the new configuration (CloudKit-backed when ON,
    ///      `.none` when OFF — per T-702's contract).
    ///
    /// **Order matters.** The flag must land *before* the rebuild — the
    /// factory reads `UserDefaults` at construction time, so swapping
    /// reads must observe the new value.
    func settingsDependencies() -> some SettingsDependencies {
        LiveSettingsDependencies { [weak self] enabled in
            // Step 1 — write the flag the container factory reads.
            UserDefaults.standard.set(enabled, forKey: RecipeStore.cloudKitSyncOptInKey)
            // Step 1b (T-707 / AC-41.9) — record the opt-in change. This is the
            // single dispatch point for `syncEnabled` / `syncDisabled`: BOTH the
            // AC-41.3 Settings toggle and the AC-41.2 first-launch prompt route
            // through this seam, so firing here covers both with no duplication.
            // The prompt's "Not now" never calls the seam, so declining
            // correctly emits nothing.
            Telemetry.shared.send(enabled ? .syncEnabled : .syncDisabled)
            // Step 2 — rebuild the container so the next open observes
            // the new value. The rebuild is best-effort: if it throws
            // (rare — only on lower-level SwiftData corruption) we log
            // and keep the stale container alive so the user can still
            // use the app per AC-41.1's graceful-fallback contract.
            do {
                let rebuilt = try RecipeStore.recreateContainerAfterOptInChange()
                await MainActor.run { [weak self] in
                    self?.modelContainer = rebuilt
                }
            } catch {
                DODLog.app.error(
                    "CloudKit opt-in container rebuild failed: \(error.localizedDescription)"
                )
            }
        }
    }

    /// Fetch a single post (by WP id) from the live REST API and project it
    /// to a ``RecipeListItem``. Backs the notification deep-link fetch-on-
    /// cache-miss path (T-632 / REG-20 / CL-101): a notification targets a
    /// brand-new post that is never cached, so `RootView.resolveRecipeRoute`
    /// calls this when `store.recipeWithoutTouching(id:)` misses, then routes
    /// to recipe-detail (which runs the JSON-LD parse / article
    /// classification to resolve recipe-vs-article per AC-4.11 / AC-37.2).
    func fetchListItem(forPostID id: Int) async throws -> RecipeListItem {
        try await restClient.post(id: id)
    }

    /// Resolve a tapped article link (a `dutchovendaddy.com` canonical URL) to
    /// a ``RecipeListItem`` by its slug — backs the in-app article recipe-link
    /// deep-link (DOD-ART-2). Returns `nil` for an off-site URL, or a
    /// `dutchovendaddy.com` URL whose slug matches no recipe/article post (a WP
    /// *page* like `/about-me/`), so `RootView` falls back to the browser.
    /// Best-effort: a network failure also yields `nil`.
    func resolveRecipe(forArticleLink url: URL) async -> RecipeListItem? {
        guard let slug = Self.recipeSlug(fromDODURL: url) else { return nil }
        return try? await restClient.post(slug: slug)
    }

    /// Extract the post slug from a `https://(www.)dutchovendaddy.com/<slug>/`
    /// permalink (DOD uses flat `/<slug>/` permalinks), or `nil` for any other
    /// host. The slug is the first non-empty path component.
    static func recipeSlug(fromDODURL url: URL) -> String? {
        guard
            let host = url.host()?.lowercased(),
            host == "dutchovendaddy.com" || host == "www.dutchovendaddy.com"
        else {
            return nil
        }
        return url.pathComponents.first { $0 != "/" && !$0.isEmpty }
    }
}

// MARK: - US-41 / AC-41.3 (T-703) live Settings wiring

/// Production conformance to ``SettingsDependencies``. Holds a
/// `@Sendable` closure that runs the two-step flag-write + container
/// rebuild on a detached `Task` so the SwiftUI alert dismiss isn't
/// blocked on the I/O. The view-model awaits the closure so the L1
/// suite can pin the order via `await`.
///
/// Spec trace: US-41 AC-41.3, AC-41.4; CL-89.
struct LiveSettingsDependencies: SettingsDependencies {

    typealias FlagWriteAndRebuild = @Sendable (Bool) async -> Void

    let flagWriteAndRebuild: FlagWriteAndRebuild

    init(flagWriteAndRebuild: @escaping FlagWriteAndRebuild) {
        self.flagWriteAndRebuild = flagWriteAndRebuild
    }

    func setCloudSyncOptIn(_ enabled: Bool) async {
        await flagWriteAndRebuild(enabled)
    }

    func cloudSyncOptInValue() -> Bool {
        UserDefaults.standard.bool(forKey: RecipeStore.cloudKitSyncOptInKey)
    }
}
