import DODDomain
import Foundation
import SwiftData

// MARK: - Container construction
//
// Extracted from RecipeStore.swift to keep that file under the
// SwiftLint 400-line file_length cap after T-620 (downloadedAt) and
// T-640 (articleBodyHTML / PostKind) both added persistence surface.
// No behavior change — these were already extension methods on
// `RecipeStore` in the main file.

extension RecipeStore {

    /// `UserDefaults` key for the CloudKit sync opt-in flag (US-41 / CL-89
    /// / AC-41.2). Default `false`. The writer of this flag is the
    /// UI layer — `T-704`'s first-launch opt-in sheet and `T-703`'s
    /// Settings → iCloud Sync toggle — and the *reader* lives here, in
    /// the container factory that decides whether to construct a plain
    /// SwiftData container or one backed by the CloudKit private DB.
    /// Pinned as a `public static let` so the UI code uses the exact
    /// same key string the container reads.
    public static let cloudKitSyncOptInKey = "dod.cloudkit.syncOptInV1"

    /// CloudKit container identifier per CL-93. Mirrors the bundle ID
    /// with the Apple-required `iCloud.` prefix. Provisioned by T-701's
    /// entitlement PR; the value here must match the
    /// `com.apple.developer.icloud-container-identifiers` array entry in
    /// `App/DODApp.entitlements`.
    public static let cloudKitContainerIdentifier =
        "iCloud.com.dutchovendaddy.DODApp"

    /// The single source-of-truth read for the CloudKit-sync opt-in flag
    /// (DUT-6). Every decision that depends on "is sync on?" — the
    /// container-configuration branch (``makeProductionConfiguration()``),
    /// the launch-time diagnostics gate in `AppDependencies.bootstrap()`,
    /// and the Settings view-model's seed state — funnels through this one
    /// reader so they can never disagree. Defaults to `false` for an absent
    /// key (a fresh install or a user who never opted in), which is the
    /// AC-41.1 graceful-fallback starting state.
    ///
    /// Exposed as a `nonisolated static` over an injectable `UserDefaults`
    /// so the L1 suite can pin the flag-as-source-of-truth contract against
    /// an isolated suite without touching `.standard`.
    public nonisolated static func cloudKitSyncOptIn(
        in defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.bool(forKey: cloudKitSyncOptInKey)
    }

    /// `UserDefaults` key for the one-time synced-saved backfill-complete flag
    /// (DUT-240). Written by `AppDependencies.backfillSyncedSavedIfNeeded` once
    /// a seed/reconcile completes; the App target reads it through this shared
    /// constant so the writer and the store's reader can never diverge.
    public static let didBackfillSyncedSavedKey = "dod.cloudkit.didBackfillSyncedSavedV1"

    /// DUT-493 — the DURABLE backfill-complete state. `RecipeStore` seeds its
    /// in-memory ``didBackfillSyncedSaved`` from this at construction so a
    /// user who finished the backfill on a PRIOR launch never opens the
    /// pre-backfill provisional-union window (DUT-470) before `bootstrap()`
    /// flips the in-memory flag — which was briefly resurrecting a
    /// cross-device-unsaved recipe on the Saved tab on every cold launch.
    /// `nonisolated static` over an injectable `UserDefaults`, mirroring
    /// ``cloudKitSyncOptIn(in:)`` so it's testable against an isolated suite.
    public nonisolated static func backfillDidComplete(
        in defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.bool(forKey: didBackfillSyncedSavedKey)
    }

    /// Create the on-disk container for production use. Pinned to
    /// `SchemaV5` — older on-disk stores migrate via `MigrationPlan` at
    /// open (V1 → V2 → V3 → V5, all lightweight; the phantom V4 is skipped).
    ///
    /// **CloudKit gating per CL-86 / CL-88 / CL-89 / CL-93.** When the
    /// `cloudKitSyncOptInKey` `UserDefaults` flag is `true` (set by
    /// T-703's Settings toggle or T-704's first-launch sheet), the
    /// configuration uses `.private(cloudKitContainerIdentifier)` so
    /// `CachedRecipe` rows where `isSaved == true` mirror to the user's
    /// iCloud private DB. When the flag is `false` (the default, or the
    /// user explicitly declined), the configuration is a plain
    /// `ModelConfiguration()` and CloudKit is never touched — the
    /// AC-41.1 graceful-fallback contract that keeps the app fully
    /// functional under no-iCloud-account + sync-declined states.
    ///
    /// **Why no `groupContainer:` parameter.** SwiftData's CloudKit
    /// adapter doesn't require the App Group container path — that's a
    /// separate widget-bridge concern handled by `WidgetImageBridge`.
    /// The CloudKit adapter writes the SwiftData store at the default
    /// app sandbox path; the App Group container is used only for the
    /// widget snapshot bytes that the widget extension reads.
    public static func productionContainer() throws -> ModelContainer {
        try productionContainer(defaults: .standard).container
    }

    /// Outcome of building the production container, distinguishing the
    /// CloudKit-backed open from the DOD-CRASH-1 safety fallback (DUT-6).
    /// The host (`AppDependencies`) reads ``usedCloudKitFallback`` to log
    /// the degraded state; the diagnostics surface keys off it so a user
    /// whose `.private` open failed sees a sensible status instead of a
    /// crash.
    public struct ContainerBuildResult {
        public let container: ModelContainer
        /// `true` when the opt-in flag was ON but the CloudKit-backed
        /// `.private` open threw, so we fell back to a plain local
        /// container. `false` on the normal opt-in or opt-out paths.
        public let usedCloudKitFallback: Bool
    }

    /// Build the production container for the *current persisted opt-in
    /// flag*, with a DOD-CRASH-1 safety net (DUT-6).
    ///
    /// The opt-in flag (read via ``cloudKitSyncOptIn(in:)``) is the single
    /// source of truth: ON ⇒ attempt a CloudKit-backed `.private`
    /// container; OFF ⇒ a plain local container. **If the opt-in path
    /// throws** — the `NSPersistentCloudKitContainer` open can fail when
    /// the Production schema was never deployed, the account is
    /// unavailable, or PushKit can't register — we **fall back to a plain
    /// local container** rather than letting the error propagate to
    /// `AppDependencies.init`'s `fatalError`. That `fatalError` is exactly
    /// what caused the build-3 DOD-CRASH-1 launch crash; this fallback is
    /// defense-in-depth so even a future schema regression degrades to
    /// "saved recipes stay on this device" instead of an unlaunchable app.
    /// The user's local data is untouched (the on-disk store path is the
    /// same for both configurations), so sync simply stays dormant until
    /// the underlying CloudKit problem is resolved and the app relaunches.
    ///
    /// The opt-OUT path is never wrapped in the fallback — a plain
    /// container that fails to open is a genuine, unrecoverable migration
    /// failure that MUST surface (MIGRATION.md discipline rule 4), so it
    /// rethrows for the caller's `fatalError` to catch.
    ///
    /// `inMemory` is a test-only seam: the L1 suite drives the exact same
    /// flag-branch + fallback logic against an in-memory store so it never
    /// touches the shared on-disk `default.store` (which carries whatever
    /// model version the host's prior runs left behind). Production always
    /// passes `false` so the real on-disk container is used.
    public static func productionContainer(
        defaults: UserDefaults,
        inMemory: Bool = false
    ) throws -> ContainerBuildResult {
        let schema = Schema(SchemaV6.models)
        // DUT-35: the six cache models are local-only; ONLY `SyncedSavedRecipe`
        // is a CloudKit-mirror candidate. Both stores live in the same
        // container, so the `@ModelActor`'s single `ModelContext` reaches both.
        let local = localCacheConfiguration(inMemory: inMemory)
        guard cloudKitSyncOptIn(in: defaults) else {
            // Opt-out: both stores local. A failure here is a real
            // migration error and must propagate.
            let container = try ModelContainer(
                for: schema,
                migrationPlan: inMemory ? nil : MigrationPlan.self,
                configurations: local,
                syncedSavedConfiguration(inMemory: inMemory, cloudKit: false)
            )
            return ContainerBuildResult(container: container, usedCloudKitFallback: false)
        }
        // Opt-in: mirror ONLY the synced store to the CloudKit private DB,
        // falling back to an all-local layout if the `.private` open throws.
        return try buildCloudKitWithFallback(
            cloudKitBuild: {
                try ModelContainer(
                    for: schema,
                    migrationPlan: inMemory ? nil : MigrationPlan.self,
                    configurations: local,
                    syncedSavedConfiguration(inMemory: inMemory, cloudKit: true)
                )
            },
            localBuild: {
                try ModelContainer(
                    for: schema,
                    migrationPlan: inMemory ? nil : MigrationPlan.self,
                    configurations: local,
                    syncedSavedConfiguration(inMemory: inMemory, cloudKit: false)
                )
            }
        )
    }

    /// The DOD-CRASH-1 safety net, extracted so the fallback branch is
    /// unit-testable by injection (a `.private` `NSPersistentCloudKitContainer`
    /// open can't be made to throw hermetically in a unit-test process —
    /// it needs the app's CloudKit/push entitlements — so the L1 suite
    /// drives a throwing `cloudKitBuild` directly to prove the catch path).
    ///
    /// Attempts `cloudKitBuild`; on **any thrown error** (schema not
    /// deployed in Production, account unavailable, PushKit registration
    /// failure) degrades to `localBuild` and reports `usedCloudKitFallback
    /// == true`, so the app launches instead of `fatalError`-ing. If the
    /// local fallback ALSO throws, that's a genuine migration failure and
    /// it rethrows for the caller's `fatalError` to surface.
    static func buildCloudKitWithFallback(
        cloudKitBuild: () throws -> ModelContainer,
        localBuild: () throws -> ModelContainer
    ) throws -> ContainerBuildResult {
        do {
            return ContainerBuildResult(container: try cloudKitBuild(), usedCloudKitFallback: false)
        } catch {
            return ContainerBuildResult(container: try localBuild(), usedCloudKitFallback: true)
        }
    }

    /// The six cache models, scoped to a **local-only** store (DUT-35). This
    /// configuration is *unnamed*, so it maps to the existing on-disk
    /// `default.store`: existing rows are preserved across the V4 -> V5
    /// migration and the only change for a previously-opted-in user is that the
    /// store's CloudKit flag flips from `.private` to `.none`. `.none` is
    /// explicit (not cosmetic): SwiftData's default `.automatic` auto-enables
    /// CloudKit whenever the app's iCloud entitlement is present, so the
    /// explicit `.none` is what keeps these six models genuinely on-device.
    private static func localCacheConfiguration(inMemory: Bool) -> ModelConfiguration {
        ModelConfiguration(
            schema: Schema(SchemaV6.localModels),
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
    }

    /// The single `SyncedSavedRecipe` model, in its own *named* store
    /// (`"SyncedSaved"`) so introducing the entity never rewrites
    /// `default.store`. Mirrors to the CloudKit private DB only when `cloudKit`
    /// is true (the opt-in path); `.none` otherwise — the opt-out path, the
    /// DOD-CRASH-1 fallback, and every in-memory test. This is the ONLY store
    /// that ever leaves the device (DUT-35 / DUT-6).
    private static func syncedSavedConfiguration(
        inMemory: Bool,
        cloudKit: Bool
    ) -> ModelConfiguration {
        ModelConfiguration(
            "SyncedSaved",
            schema: Schema(SchemaV6.syncedModels),
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKit ? .private(cloudKitContainerIdentifier) : .none
        )
    }

    /// Build a fresh production container matching the *current* persisted
    /// opt-in flag. Retained as a named seam for symmetry with the launch
    /// path, but **the opt-in toggle no longer hot-swaps the live store**
    /// (DUT-6): SwiftData binds a `ModelContainer` (and the `@ModelActor`
    /// `RecipeStore` built from it) once per process and cannot swap the
    /// `cloudKitDatabase` configuration mid-flight, and the app injects no
    /// `ModelContainer` into the SwiftUI environment, so reassigning a
    /// rebuilt container in the composition root re-wired nothing while
    /// adding a transient second `NSPersistentCloudKitContainer` (a
    /// DOD-CRASH-1 risk surface).
    ///
    /// The persisted flag is therefore the single source of truth, read at
    /// the *next* launch by ``productionContainer(defaults:)``. The toggle's
    /// job is just to write the flag (and tell the user a relaunch applies
    /// it); this function exists for any caller that genuinely wants a
    /// flag-matched container instance (e.g. a future cold re-bootstrap),
    /// not for mid-session swapping.
    public static func recreateContainerAfterOptInChange() throws -> ModelContainer {
        try productionContainer()
    }

    /// Internal seam — chooses the right `ModelConfiguration` for the
    /// current opt-in state. Factored out of `productionContainer()` so
    /// tests can verify the no-CloudKit branch without spinning up a
    /// `CKContainer` reference (per AC-41.1 / REG-26).
    ///
    /// **Why `.none` is explicit on the opt-out branch.** SwiftData's
    /// default `ModelConfiguration` uses `.automatic` for the
    /// `cloudKitDatabase:` parameter, and `.automatic` auto-enables
    /// CloudKit sync whenever the app's entitlements file declares
    /// `com.apple.developer.icloud-container-identifiers` (which T-701
    /// added). Setting `.none` explicitly is the AC-41.1 graceful-fallback
    /// contract: the entitlement stays in place for users who DO opt in,
    /// but CloudKit is provably not touched until the opt-in flag flips —
    /// so the app works identically for users not signed into iCloud or
    /// who declined sync.
    ///
    /// **Schema is CloudKit-ready (T-702b + DOD-CRASH-1).** CloudKit's
    /// mirroring invariants forbid `@Attribute(.unique)` constraints AND
    /// require every attribute to be optional or carry a default value.
    /// Both halves are load-bearing:
    ///
    /// 1. The five unique constraints (`CachedRecipe.id`, `CachedComment.id`,
    ///    `CachedRating.recipeID`, `CachedListPage.key`,
    ///    `CachedImage.urlString`) were dropped — redundant, since
    ///    `RecipeStore` dedups every insert via explicit fetch-or-create.
    /// 2. **DOD-CRASH-1:** dropping the unique constraints alone was NOT
    ///    enough — the `@Model` classes still had dozens of non-optional
    ///    attributes with no default value (`id: Int`, `title: String`,
    ///    `bytes: Data`, …), which CloudKit also rejects. The opt-in
    ///    `.private(...)` container therefore still threw at open, and
    ///    `AppDependencies.init`'s `fatalError` crashed the app on every
    ///    relaunch once sync was enabled (build 3 regression). The fix
    ///    gives every non-optional attribute a default value; defaults are
    ///    NOT part of the Core Data version hash, so existing on-disk
    ///    stores keep opening with no migration. Guarded by
    ///    `CloudKitSchemaCompatibilityTests` — no prior test built a
    ///    `.private` container, which is how this shipped.
    static func makeProductionConfiguration() -> ModelConfiguration {
        // DUT-35: the CloudKit flag now lives on the synced sub-store only, so
        // this seam returns that store's configuration. The opt-in -> `.private`
        // / opt-out -> `.none` contract stays directly assertable in the L1
        // suite (CloudKitContainerSelectionTests / SchemaV5Tests).
        syncedSavedConfiguration(inMemory: false, cloudKit: cloudKitSyncOptIn())
    }

    /// Create an in-memory container for tests. Uses the current schema so
    /// fixture data exercises the same models the app ships with.
    public static func inMemoryContainer() throws -> ModelContainer {
        // Same two-configuration topology as production (DUT-35), both
        // in-memory and both `.none`. `cloudKitDatabase: .none` is REQUIRED,
        // not cosmetic: the app target's iCloud entitlements (T-701) make
        // SwiftData's default `.automatic` auto-enable CloudKit, which is
        // invalid for an in-memory store and crashes at container open. The app
        // reaches this via the `-DODUseInMemoryStore` UI-test hook in
        // `AppDependencies`; the L1 suite reaches it directly.
        try ModelContainer(
            for: Schema(SchemaV6.models),
            configurations: localCacheConfiguration(inMemory: true),
            syncedSavedConfiguration(inMemory: true, cloudKit: false)
        )
    }

    /// Create an in-memory container at the legacy V1 schema. Used only by
    /// the V1→V2 migration test to prove a pre-US-12 store opens cleanly
    /// under V2. Production code never calls this.
    public static func inMemoryContainerV1() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(SchemaV1.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Create an in-memory container at the V2 schema. Used only by the
    /// V2→V3 migration test to prove a pre-US-13/14 store opens cleanly
    /// under V3. Production code never calls this.
    public static func inMemoryContainerV2() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(SchemaV2.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Create an in-memory container at the V3 schema. Used only by the
    /// V3→V4 migration test to prove a pre-US-41 store opens cleanly
    /// under V4. Production code never calls this.
    public static func inMemoryContainerV3() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(SchemaV3.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
