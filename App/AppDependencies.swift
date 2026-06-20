import CloudKit
import DODAnalytics
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
    /// Built once per process from the persisted opt-in flag (DUT-6) and
    /// never swapped — SwiftData can't hot-swap a container's CloudKit
    /// configuration mid-flight, so the flag is re-read at the next launch
    /// instead. `let`, not `var`, to make that immutability enforced.
    let modelContainer: ModelContainer

    /// On-device local-notification service (US-42 / T-631). Long-lived —
    /// owns the authorization request the Settings toggle drives and the
    /// scheduling the (DEBUG) test affordance fires. No APNs / no server.
    let notificationService: NotificationService

    // Module-internal (was `private`) so the article/slug-resolution helpers
    // extracted to `AppDependencies+RecipeResolution.swift` (T-791 file-length
    // trim) can reach the REST client.
    let restClient: WPRestClient
    private let pageFetcher: RecipePageFetcher
    private let imageLoader: ImageLoader
    private let networkMonitor: NetworkMonitor
    private let commentsClient: WPCommentsClient
    private let ratingsClient: WPRMRatingsClient
    private let guestIdentityStore: any GuestIdentityStoring
    /// US-44 (T-739) — Keychain profile store. Phase b (T-740) — wired
    /// with the photo store so `clear()` also deletes the on-disk JPG.
    let profileStore: KeychainProfileStore
    /// US-44 Phase b (T-740) — Documents JPG (512×512 @ 0.85). `nil` if
    /// Documents is unavailable; photo flow falls back to the initial-
    /// letter avatar. Per CL-137 / AC-44.9.
    let profilePhotoStore: ProfilePhotoStore?

    /// Diagnostic observer for the SwiftData ↔ CloudKit mirror (round-12
    /// backlog bug — "CloudKit recipe sync doesn't work"). Started from
    /// `bootstrap()` only when the iCloud-Sync opt-in is on.
    private let cloudKitDiagnostics = CloudKitSyncDiagnostics()

    /// `true` when the persisted opt-in flag was ON but the CloudKit-backed
    /// `.private` container failed to open at launch, so the DOD-CRASH-1
    /// safety net (DUT-6) degraded to a plain local container. Surfaced to
    /// the diagnostics log; sync stays dormant (local data intact) until the
    /// underlying CloudKit problem — most likely an undeployed Production
    /// schema — is fixed and the app relaunches.
    private let usedCloudKitFallback: Bool

    /// `true` when the DUT-78 self-heal escape hatch tripped this launch:
    /// the app had crash-looped, so we force-opened a local container and
    /// cleared the opt-in flag. Surfaced once in `bootstrap()` so a device
    /// log shows the recovery happened.
    private let didSelfHeal: Bool

    /// The DUT-78 self-heal escape hatch. Records "a launch started but isn't
    /// yet healthy" at the very start of `init()`; `bootstrap()` calls
    /// ``LaunchHealthTracker/markLaunchHealthy()`` once the app is up. A launch
    /// that crashes in between (e.g. the async CloudKit mirroring trap) leaves
    /// the counter incremented, so after a few crash-looping launches the
    /// container build force-opens local and we clear the opt-in flag.
    private let launchHealth = LaunchHealthTracker()

    private let usedInMemoryStore: Bool

    init() {
        var fellBackToLocal = false
        var healed = false
        var inMemory = false
        // DUT-78 self-heal: stamp this launch as "started, not yet healthy"
        // BEFORE building any SwiftData/CloudKit container, so a launch that
        // traps in async CloudKit mirroring is counted. `bootstrap()` resets
        // the counter once the app is on screen.
        launchHealth.recordLaunchStarted()
        do {
            // L3 isolation hook: `-DODUseInMemoryStore` gives each UI-test
            // launch a clean, empty SwiftData store so saved recipes don't
            // persist across runs on a shared CI simulator (the cause of the
            // flaky "No saved recipes yet" empty-state assertions). Never set
            // in production — the app always uses the on-disk container.
            if ProcessInfo.processInfo.arguments.contains("-DODUseInMemoryStore") {
                self.modelContainer = try RecipeStore.inMemoryContainer()
                inMemory = true
            } else {
                // DUT-6 + DUT-78: build the container for the persisted opt-in
                // flag with three layered safety nets: (1) DOD-CRASH-1 wraps
                // the synchronous `.private` open in do/catch; (2) the DUT-78
                // pre-open account-status guard passes the status the previous
                // launch's `bootstrap()` probe cached (the build is sync, the
                // probe async), so a non-`.available` account opens local
                // instead of `.private(...)` — dodging the async
                // `com.apple.coredata.cloudkit.queue` trap that fires AFTER the
                // synchronous open returns and so escapes net #1; (3) the
                // DUT-78 self-heal escape hatch (`launchHealth`) forces local +
                // clears the opt-in flag below after repeated crash-loops.
                let result = try RecipeStore.productionContainer(
                    defaults: .standard,
                    accountStatus: CloudKitAvailability.cachedAccountStatus(in: .standard),
                    launchHealth: launchHealth
                )
                self.modelContainer = result.container
                fellBackToLocal = result.usedCloudKitFallback
                healed = result.didSelfHeal
                if result.didSelfHeal {
                    // DUT-78: crash-looped → force-opened local. Clear the
                    // opt-in flag so the NEXT launch opens local cleanly (no
                    // probe, no `.private`) without re-tripping the heal; the
                    // user re-enables sync from Settings once iCloud is fixed.
                    UserDefaults.standard.set(false, forKey: RecipeStore.cloudKitSyncOptInKey)
                }
            }
        } catch {
            // Schema migration failure must surface to the user (MIGRATION.md
            // discipline rule 4). For v1 we crash early so the issue is
            // unambiguous in TestFlight feedback.
            fatalError("SwiftData migration failed: \(error)")
        }
        self.usedCloudKitFallback = fellBackToLocal
        self.didSelfHeal = healed
        self.usedInMemoryStore = inMemory
        self.store = RecipeStore(modelContainer: modelContainer)
        self.restClient = WPRestClient()
        self.pageFetcher = RecipePageFetcher()
        self.imageLoader = ImageLoader()
        self.networkMonitor = NetworkMonitor.shared
        // US-13/14/15 integration: the comments + ratings + guest-identity
        // clients are constructed alongside the rest of the long-lived
        // services and handed to `LiveRecipeDetailDependencies` on demand.
        // DUT-23: pass the app-identity key (Info.plist `DODCommentAPIKey`,
        // injected at archive time from the DOD_COMMENT_API_KEY CI secret) so
        // the comment POST carries `X-DOD-App-Key` and WordPress allows the
        // app's anonymous comments. nil/empty in dev + PR builds.
        self.commentsClient = WPCommentsClient(
            appKey: Bundle.main.object(forInfoDictionaryKey: "DODCommentAPIKey") as? String
        )
        self.ratingsClient = WPRMRatingsClient()
        self.guestIdentityStore = KeychainGuestIdentityStore()
        // Phase b (T-740) — wire the on-disk photo store into the
        // profile store so Sign Out + Delete Profile clean up both
        // surfaces per CL-137 / AC-44.9. A throw degrades to nil and
        // the flow falls back to the initial-letter avatar.
        let resolvedPhotoStore = try? ProfilePhotoStore()
        self.profilePhotoStore = resolvedPhotoStore
        self.profileStore = KeychainProfileStore(photoStore: resolvedPhotoStore)
        self.notificationService = NotificationService()
    }

    /// Called once from `@main` at app launch.
    func bootstrap() async {
        // DUT-78 self-heal: reaching `bootstrap()` means the app survived the
        // synchronous container build and the scene is up — well past the
        // window in which the async CloudKit mirroring trap fires. Reset the
        // consecutive-unhealthy-launch counter so a single later unrelated
        // crash doesn't accumulate toward the self-heal threshold.
        launchHealth.markLaunchHealthy()
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
        // DUT-35: one-time backfill of the synced saved-set from any pre-V5
        // local saves, so the Saved tab isn't empty after the update that
        // scoped CloudKit sync down to `SyncedSavedRecipe`. Runs regardless of
        // opt-in (so the synced store is already seeded if the user opts in
        // later) and exactly once (see `backfillSyncedSavedIfNeeded`).
        await backfillSyncedSavedIfNeeded()
        // DUT-78: if the self-heal escape hatch tripped, surface it once for
        // the device log (the opt-in flag was force-cleared in `init`).
        if didSelfHeal {
            cloudKitDiagnostics.markContainerOpenFailed()
            // Single string literal: `os.Logger` needs an `OSLogMessage` (a `+`-concatenated `String` won't convert) and a static literal logs unredacted.
            DODLog.app.error(
                "CloudKit sync self-healed (DUT-78): app had crash-looped, so sync was force-disabled and a local-only store opened. Re-enable from Settings once iCloud is signed in / the schema is deployed."
            )
        }
        // The in-memory UI-test store never engages CloudKit — skip the block.
        guard !usedInMemoryStore else { return }
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
                // DUT-78: a previously-CloudKit store is now TAINTED — Core
                // Data stamped it for mirroring, so even a `.none` reopen can
                // re-trigger it. Log so a device follow-up can decide on a
                // clean store rebuild.
                if RecipeStore.cloudKitStoreEverOpened(in: .standard) {
                    DODLog.app.error(
                        "DUT-78: synced store likely tainted (was CloudKit-backed); a `.none` reopen can still re-trigger mirroring."
                    )
                }
            }
            await checkCloudKitAvailability()
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
        // US-44 / CL-138 / T-741 — thread the Phase a profile store
        // and the Phase b photo store into recipe-detail so the
        // Ratings & Reviews gate can (a) read `hasProfile` via
        // `loadUserProfile()`, and (b) present `ProfileEditView` as a
        // modal sheet over the recipe with the same photo flow the
        // Settings entry path uses.
        LiveRecipeDetailDependencies(
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
            savedWidgetPublisher: savedWidgetPublisher()
        )
    }

    /// Build a fully-wired saved-recipes widget publisher: the store, the
    /// WidgetKit reload hook (the `kind` is pinned by spec.md AC-17.6 — it must
    /// match the widget's `kind`), and the hero-image prefetcher that bridges
    /// saved-recipe photos into the App Group container so the widget renders
    /// them (T-770 / CL-167 / DUT-76). Both the recipe-detail save path
    /// (above) and the card long-press save path (`TabStack.saveFromCard`) use
    /// this, so the prefetch runs regardless of where the save originates. The
    /// prefetch closure mirrors the feed's (`feedDependencies()` above): route
    /// hero URLs through `ImageLoader` + `RecipeStore.cacheImage`, which writes
    /// the bridge file via `WidgetImageBridge`.
    func savedWidgetPublisher() -> SavedRecipesWidgetPublisher {
        let reload: SavedRecipesWidgetPublisher.ReloadHook = {
            WidgetCenter.shared.reloadTimelines(ofKind: "SavedRecipesWidget")
        }
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
        // DUT-6 (UI-refresh half): feed the Saved view model a stream of
        // CloudKit remote-import signals so a recipe saved on another device
        // appears here without a relaunch. The stream is built in the App
        // target (the only place CloudKit + Core Data are linked) from
        // `NotificationCenter`; the `DODFeatureSaved` package consumes it
        // abstractly through the `SavedDependencies.remoteChanges()` seam.
        LiveSavedDependencies(
            store: store,
            imageLoader: imageLoader,
            remoteChangeStream: { SavedRemoteChangeBridge.makeStream() },
            // DUT-84 — connectivity for the offline remove-download guard.
            monitor: networkMonitor
        )
    }

    /// US-41 / AC-41.3 (T-703) + DUT-6. Build the Settings dependency
    /// surface for the iCloud Sync toggle. Its single job is to **persist
    /// the opt-in flag** — `RecipeStore.cloudKitSyncOptInKey` is the single
    /// source of truth, read at the *next* launch by
    /// `RecipeStore.productionContainer(defaults:)` to decide whether to
    /// build a CloudKit-backed or a plain local container.
    ///
    /// **Why no mid-session container rebuild (the DUT-6 fix).** The
    /// pre-DUT-6 code rebuilt the `ModelContainer` here and reassigned
    /// `self.modelContainer`. That re-wired *nothing*: SwiftData binds a
    /// container (and the `@ModelActor` `RecipeStore` built from it) once
    /// per process and can't hot-swap the `cloudKitDatabase` configuration
    /// mid-flight, the live `RecipeStore` was never rebuilt, and the app
    /// injects no `ModelContainer` into the SwiftUI environment — so the
    /// reassignment only added a transient second
    /// `NSPersistentCloudKitContainer` (a DOD-CRASH-1 risk surface) while
    /// the running store kept its old configuration. Sync therefore only
    /// ever engaged on the next cold launch anyway. We make that honest:
    /// write the flag, let the view-model tell the user a relaunch applies
    /// it, and build the right container deterministically at launch.
    func settingsDependencies() -> some SettingsDependencies {
        let diagnostics = cloudKitDiagnostics
        return LiveSettingsDependencies(
            flagWrite: { enabled in
                // Persist the flag the launch-time container factory reads.
                UserDefaults.standard.set(enabled, forKey: RecipeStore.cloudKitSyncOptInKey)
                // T-707 / AC-41.9 — record the opt-in change. This is the
                // single dispatch point for `syncEnabled` / `syncDisabled`:
                // BOTH the AC-41.3 Settings toggle and the AC-41.2
                // first-launch prompt route through this seam, so firing here
                // covers both with no duplication. The prompt's "Not now"
                // never calls the seam, so declining correctly emits nothing.
                Telemetry.shared.send(enabled ? .syncEnabled : .syncDisabled)
            },
            statusProvider: {
                // DUT-6 cause B: surface the App-target mirror observer's
                // latest coarse status to the Settings row. Read on the main
                // actor (the Settings view calls this on appear).
                MainActor.assumeIsolated { diagnostics.latestStatus }
            }
        )
    }
}
