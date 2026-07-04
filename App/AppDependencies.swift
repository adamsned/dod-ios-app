import CloudKit
import DODAnalytics
import DODDesignSystem
import DODDomain
import DODFeatureCategories
import DODFeatureFeed
import DODFeatureProfile
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
    /// Built once per process from the persisted opt-in flag (DUT-6) and never
    /// swapped — SwiftData can't hot-swap a container's CloudKit config mid-flight,
    /// so the flag is re-read next launch. `let` makes that immutability enforced.
    let modelContainer: ModelContainer

    /// On-device local-notification service (US-42 / T-631). Long-lived — owns the
    /// authorization request the Settings toggle drives and the scheduling the
    /// (DEBUG) test affordance fires. No APNs / no server.
    let notificationService: NotificationService

    let restClient: WPRestClient  // internal for +ShoppingList searchDeps (DUT-534)
    let pageFetcher: RecipePageFetcher  // internal for +WidgetClassifier (DUT-460)
    private let imageLoader: ImageLoader
    let networkMonitor: NetworkMonitor  // internal for +ShoppingList searchDeps (DUT-534)
    private let commentsClient: WPCommentsClient
    private let ratingsClient: WPRMRatingsClient
    private let guestIdentityStore: any GuestIdentityStoring
    /// US-44 (T-739) — Keychain profile store. Phase b (T-740) — wired with the
    /// photo store so `clear()` also deletes the on-disk JPG.
    let profileStore: KeychainProfileStore
    /// US-44 Phase b (T-740) — Documents JPG (512×512 @ 0.85). `nil` if Documents
    /// is unavailable; photo flow falls back to the initial-letter avatar. Per
    /// CL-137 / AC-44.9.
    let profilePhotoStore: ProfilePhotoStore?

    /// Diagnostic observer for the SwiftData ↔ CloudKit mirror (round-12 backlog
    /// bug — "CloudKit recipe sync doesn't work"). Started from `bootstrap()` only
    /// when the iCloud-Sync opt-in is on.
    private let cloudKitDiagnostics = CloudKitSyncDiagnostics()

    /// `true` when the persisted opt-in flag was ON but the CloudKit-backed
    /// `.private` container failed to open at launch, so the DOD-CRASH-1 safety
    /// net (DUT-6) degraded to a plain local container. Sync stays dormant (local
    /// data intact) until the CloudKit problem is fixed and the app relaunches.
    /// Internal so `+SyncedSavedBackfill.swift` can gate the DUT-240 seed on it.
    let usedCloudKitFallback: Bool

    /// DUT-494 — synced saved-id baseline captured SYNCHRONOUSLY in `init` (pre run
    /// loop, pre-import) so the async CloudKit import can't fold device B's rows in
    /// and poison the seed. See `backfillSyncedSavedIfNeeded`.
    let processStartSyncedIDs: Set<Int>

    init() {
        var fellBackToLocal = false
        do {
            // L3 isolation hook (`-DODUseInMemoryStore`) + T-610 hermetic E2E
            // both use a clean in-memory store so nothing persists across runs
            // on a shared CI simulator. Never used in production.
            if Self.useInMemoryStore() {
                self.modelContainer = try RecipeStore.inMemoryContainer()
            } else {
                // DUT-6: build the container for the persisted opt-in flag WITH
                // the DOD-CRASH-1 safety net — if the CloudKit `.private` open
                // throws, `productionContainer(defaults:)` falls back to a plain
                // local container so the app launches instead of crash-looping
                // (build 3). A plain opt-out open failure is a real migration
                // error and surfaces via the `fatalError` below (MIGRATION rule 4).
                let result = try RecipeStore.productionContainer(defaults: .standard)
                self.modelContainer = result.container
                fellBackToLocal = result.usedCloudKitFallback
            }
        } catch {
            // Schema migration failure must surface to the user (MIGRATION.md
            // discipline rule 4). For v1 we crash early so the issue is
            // unambiguous in TestFlight feedback.
            fatalError("SwiftData migration failed: \(error)")
        }
        self.usedCloudKitFallback = fellBackToLocal
        // DUT-494: anchor the synced-saved baseline synchronously, pre run loop.
        self.processStartSyncedIDs = (try? RecipeStore.syncedSavedIDSet(in: modelContainer)) ?? []
        self.store = RecipeStore(modelContainer: modelContainer)
        // T-610: shared HTTPClient (canned stub in E2E) — see AppDependencies+E2E.
        let httpClient = Self.makeHTTPClient()
        self.restClient = WPRestClient(httpClient: httpClient)
        self.pageFetcher = RecipePageFetcher(httpClient: httpClient)
        self.imageLoader = ImageLoader(httpClient: httpClient)
        self.networkMonitor = NetworkMonitor.shared
        // US-13/14/15 integration: the comments + ratings + guest-identity
        // clients are constructed alongside the rest of the long-lived
        // services and handed to `LiveRecipeDetailDependencies` on demand.
        // DUT-23: pass the app-identity key (Info.plist `DODCommentAPIKey`,
        // injected at archive time from the DOD_COMMENT_API_KEY CI secret) so
        // the comment POST carries `X-DOD-App-Key` and WordPress allows the
        // app's anonymous comments. nil/empty in dev + PR builds.
        self.commentsClient = WPCommentsClient(
            httpClient: httpClient,
            appKey: Bundle.main.object(forInfoDictionaryKey: "DODCommentAPIKey") as? String
        )
        self.ratingsClient = WPRMRatingsClient(httpClient: httpClient)
        self.guestIdentityStore = KeychainGuestIdentityStore()
        // Phase b (T-740) — wire the on-disk photo store into the
        // profile store so Sign Out + Delete Profile clean up both
        // surfaces per CL-137 / AC-44.9. A throw degrades to nil and
        // the flow falls back to the initial-letter avatar.
        let resolvedPhotoStore = try? ProfilePhotoStore()
        self.profilePhotoStore = resolvedPhotoStore
        self.profileStore = KeychainProfileStore(photoStore: resolvedPhotoStore)
        self.notificationService = NotificationService()
        Self.installBridgedEvictionHook { WidgetCenter.shared.reloadAllTimelines() }  // DUT-475: pre-UI
    }

    /// Called once from `@main` at app launch.
    func bootstrap() async {
        await networkMonitor.start()
        // DUT-377: ReliableImage offline disk fallback (saved/downloaded heroes).
        ReliableImageConfig.setOfflineDataProvider { [store] url in try? await store.image(url: url) }
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
        // DUT-35: one-time backfill of the synced saved-set from any pre-V5
        // local saves, so the Saved tab isn't empty after the update that
        // scoped CloudKit sync down to `SyncedSavedRecipe`. Runs regardless of
        // opt-in (so the synced store is already seeded if the user opts in
        // later) and exactly once (see `backfillSyncedSavedIfNeeded`).
        await backfillSyncedSavedIfNeeded()
        // US-41 / AC-41.1 (T-702): conditional CloudKit availability
        // check. Only fires when the user has opted into iCloud sync via
        // T-703's Settings toggle or T-704's first-launch sheet —
        // otherwise the app never touches `CKContainer` at all, which is
        // the AC-41.1 graceful-fallback contract that keeps the existing
        // v1.0 behavior intact under no-iCloud-account + sync-declined
        // states.
        if RecipeStore.cloudKitSyncOptIn() {
            // Round-12 backlog bug: log every CloudKit mirror event so an
            // on-device run reveals which layer fails (schema / account /
            // never-enabled). Pairs with the account-status probe below.
            cloudKitDiagnostics.start()
            // DUT-6: if the CloudKit container couldn't open at launch we
            // already degraded to a local store (DOD-CRASH-1 safety net);
            // make that explicit in the log so a device run shows "sync was
            // on but the mirror never engaged" rather than silence. The most
            // likely cause is a Production schema that was never deployed.
            if usedCloudKitFallback {
                DODLog.app.error(
                    """
                    CloudKit sync is ON but the CloudKit container failed to open; \
                    running on a local-only store this launch (saved recipes stay on \
                    this device). Most likely the CloudKit Production schema was never \
                    deployed — deploy it from the CloudKit Console, then relaunch.
                    """
                )
                // DUT-22: this fallback fires NO mirror events, so surface it
                // as a real error instead of letting the Settings row read a
                // falsely-healthy "Idle".
                cloudKitDiagnostics.markContainerOpenFailed()
            }
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
        // Fixes REG-T-360 / CL-45. The snapshot's `heroImageFilename`s are
        // SHA256-of-URL, but bridge files only exist once `cacheImage` writes
        // them — this prefetcher routes the snapshotted hero URLs through the
        // same path, fire-and-forget inside `publishWidgetSnapshot`.
        let loader = imageLoader
        let cacheStore = store
        let prefetch: LiveFeedDependencies.ImagePrefetcher = { urls in
            for url in urls {
                // DUT-420/442: skip fully-bridged URLs — the probe doesn't bump
                // the LRU / fault the blob, and requires the App Group FILE too
                // (a lost bridge write still self-heals). See `hasBridgedImage`.
                if (try? await cacheStore.hasBridgedImage(url: url)) == true { continue }
                guard let bytes = try? await loader.data(for: url) else { continue }
                try? await cacheStore.cacheImage(url: url, bytes: bytes)
            }
        }
        // DUT-534 Part 2 — same append seam Recipe Detail (Part 1) + Search use;
        // the appender hydrates the ingredient-empty card recipe before appending.
        let appender = shoppingListAppender()
        return LiveFeedDependencies(
            client: restClient,
            store: store,
            monitor: networkMonitor,
            widgetReload: reload,
            imagePrefetcher: prefetch,
            latestKindClassifier: makeLatestKindClassifier(),  // DUT-460 adaptive eyebrow
            shoppingListAppend: { recipe in await appender.addToShoppingList(recipe) }
        )
    }

    func categoriesDependencies() -> some CategoriesDependencies {
        LiveCategoriesDependencies(client: restClient, store: store)
    }

    func recipeDetailDependencies() -> some RecipeDetailDependencies {
        // US-44 / CL-138 / T-741 — thread the Phase a profile store + the Phase b
        // photo store into recipe-detail so the Ratings & Reviews gate can read
        // `hasProfile` via `loadUserProfile()` and present `ProfileEditView` as a
        // modal sheet over the recipe with the same photo flow Settings uses.
        let appender = shoppingListAppender()
        return LiveRecipeDetailDependencies(
            client: restClient,
            fetcher: pageFetcher,
            store: store,
            monitor: networkMonitor,
            commentsClient: commentsClient,
            ratingsClient: ratingsClient,
            guestIdentity: guestIdentityStore,
            profileStore: profileStore,
            profilePhotoStore: profilePhotoStore,
            imageLoader: imageLoader,
            savedWidgetPublisher: savedWidgetPublisher(),
            // DUT-534 — "Add to Shopping List" seam (Detail recipe already loaded).
            appendToShoppingList: { recipe in await appender.addToShoppingList(recipe) }
        )
    }

    /// Build a fully-wired saved-recipes widget publisher: the store, the WidgetKit
    /// reload hook (the `kind` is pinned by spec.md AC-17.6 — it must match the
    /// widget's `kind`), and the hero-image prefetcher that bridges saved-recipe
    /// photos into the App Group container so the widget renders them (T-770 /
    /// CL-167 / DUT-76). Both the recipe-detail save path (above) and the card
    /// long-press save path (`TabStack.saveFromCard`) use this. The prefetch closure
    /// mirrors the feed's (`feedDependencies()` above): route hero URLs through
    /// `ImageLoader` + `RecipeStore.cacheImage`, which writes the bridge file via
    /// `WidgetImageBridge`.
    func savedWidgetPublisher() -> SavedRecipesWidgetPublisher {
        // DUT-453 — reload all kinds so the lock-screen Saved count refreshes too.
        let reload: SavedRecipesWidgetPublisher.ReloadHook = { WidgetCenter.shared.reloadAllTimelines() }
        let loader = imageLoader
        let cacheStore = store
        let prefetch: SavedRecipesWidgetPublisher.ImagePrefetcher = { urls in
            for url in urls {
                guard let bytes = try? await loader.data(for: url) else { continue }
                try? await cacheStore.cacheImage(url: url, bytes: bytes)
            }
        }
        return SavedRecipesWidgetPublisher(store: store, reload: reload, imagePrefetcher: prefetch)
    }

    func savedDependencies() -> some SavedDependencies {
        // DUT-6 (UI-refresh half): feed the Saved view model a stream of CloudKit
        // remote-import signals so a recipe saved on another device appears here
        // without a relaunch. The stream is built in the App target (the only place
        // CloudKit + Core Data are linked) from `NotificationCenter`; `DODFeatureSaved`
        // consumes it abstractly through the `SavedDependencies.remoteChanges()` seam.
        let widgetPublisher = savedWidgetPublisher()
        return LiveSavedDependencies(
            store: store,
            imageLoader: imageLoader,
            pageFetcher: pageFetcher,  // DUT-487 — hydrate ingredients for the shopping list
            remoteChangeStream: { SavedRemoteChangeBridge.makeStream() },
            monitor: networkMonitor,  // DUT-84 — offline remove-download guard
            publishWidget: { await widgetPublisher.publish() }  // DUT-365 widget republish
        )
    }

    /// US-41 / AC-41.3 (T-703) + DUT-6. Build the Settings dependency surface for
    /// the iCloud Sync toggle. Its single job is to **persist the opt-in flag** —
    /// `RecipeStore.cloudKitSyncOptInKey` is the single source of truth, read at the
    /// *next* launch by `RecipeStore.productionContainer(defaults:)` to decide
    /// whether to build a CloudKit-backed or a plain local container.
    ///
    /// **Why no mid-session container rebuild (the DUT-6 fix).** The pre-DUT-6 code
    /// rebuilt the `ModelContainer` here and reassigned `self.modelContainer`. That
    /// re-wired *nothing*: SwiftData binds a container (and the `@ModelActor`
    /// `RecipeStore` built from it) once per process and can't hot-swap the
    /// `cloudKitDatabase` config mid-flight, the live `RecipeStore` was never
    /// rebuilt, and the app injects no `ModelContainer` into the SwiftUI environment
    /// — so the reassignment only added a transient second
    /// `NSPersistentCloudKitContainer` (a DOD-CRASH-1 risk surface) while the running
    /// store kept its old config. Sync therefore only ever engaged on the next cold
    /// launch anyway. We make that honest: write the flag, let the view-model tell
    /// the user a relaunch applies it, and build the right container at launch.
    func settingsDependencies() -> some SettingsDependencies {
        let diagnostics = cloudKitDiagnostics
        return LiveSettingsDependencies(
            flagWrite: { enabled in
                UserDefaults.standard.set(enabled, forKey: RecipeStore.cloudKitSyncOptInKey)
                // T-707 / AC-41.9 — single dispatch point for syncEnabled /
                // syncDisabled: BOTH the Settings toggle and the first-launch
                // prompt route here (the prompt's "Not now" never calls the seam,
                // so declining emits nothing).
                Telemetry.shared.send(enabled ? .syncEnabled : .syncDisabled)
            },
            statusProvider: {
                // DUT-6 cause B: surface the App-target mirror observer's latest
                // coarse status (read on the main actor; Settings calls on appear).
                MainActor.assumeIsolated { diagnostics.latestStatus }
            },
            // DUT-417 — profile-stats data, read from the on-device store.
            cookLogsLoad: { [store] in try await store.allCookLogs() },
            savedCountLoad: { [store] in try await store.savedRecipes().count },
            ratingCountLoad: { [store] in try await store.userRatingCount() },
            cookLogWrite: { [store] entry in try await store.updateCookLog(entry) },
            // DUT-514 — delete cascades the entry's photo (RecipeStore.deleteCookLog).
            cookLogDelete: { [store] id in try await store.deleteCookLog(id: id) }
        )
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
