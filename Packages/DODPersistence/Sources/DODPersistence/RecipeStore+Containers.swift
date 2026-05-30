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

    /// Create the on-disk container for production use. Pinned to
    /// `SchemaV4` — older on-disk stores migrate via `MigrationPlan` at
    /// open (V1 → V2 → V3 → V4, all lightweight).
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
        let configuration = makeProductionConfiguration()
        return try ModelContainer(
            for: Schema(SchemaV4.models),
            migrationPlan: MigrationPlan.self,
            configurations: configuration
        )
    }

    /// Rebuild the production container after the opt-in flag changes
    /// (e.g., the user toggles Settings → iCloud Sync on or off). The
    /// caller is responsible for replacing the stale `ModelContainer` in
    /// the composition root and re-wiring downstream consumers
    /// (`RecipeStore`, the App Intents environment, the widget
    /// publishers). T-703 owns the wiring; T-702 owns this seam.
    ///
    /// **Why a public seam instead of observing `UserDefaults` from the
    /// container.** A `ModelContainer` is constructed once per process
    /// lifecycle; SwiftData doesn't support swapping its
    /// `ModelConfiguration` mid-flight. The opt-in transition requires
    /// the host to discard the old container and build a fresh one with
    /// the new configuration. Exposing the rebuild as an explicit
    /// function keeps that contract visible at the call site.
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
    /// **Schema is CloudKit-ready (T-702b).** CloudKit's mirroring
    /// invariants forbid `@Attribute(.unique)` constraints and require
    /// every attribute to be optional or defaulted. The five unique
    /// constraints that shipped through SchemaV4 (`CachedRecipe.id`,
    /// `CachedComment.id`, `CachedRating.recipeID`, `CachedListPage.key`,
    /// `CachedImage.urlString`) were dropped — they were redundant, since
    /// `RecipeStore` already dedups every insert via explicit
    /// fetch-or-create (`let existing = try fetchRecipe(id:)` …), so the
    /// DB-level constraint was belt-and-suspenders, not load-bearing. With
    /// them gone, the `.private(...)` branch opens cleanly instead of
    /// crashing at container open. The removal is a non-destructive,
    /// in-place schema relaxation (no row violates a dropped constraint),
    /// mirroring how the additive `articleBodyHTML` column migrated
    /// without a dedicated stage.
    static func makeProductionConfiguration() -> ModelConfiguration {
        let optedIn = UserDefaults.standard.bool(forKey: cloudKitSyncOptInKey)
        if optedIn {
            return ModelConfiguration(
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        }
        return ModelConfiguration(cloudKitDatabase: .none)
    }

    /// Create an in-memory container for tests. Uses the current schema so
    /// fixture data exercises the same models the app ships with.
    public static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(SchemaV4.models),
            // `cloudKitDatabase: .none` is REQUIRED, not cosmetic. The app
            // target's iCloud entitlements (T-701) make SwiftData's default
            // `.automatic` auto-enable CloudKit, which is invalid for an
            // in-memory store and crashes at container open. Unit tests run
            // without the entitlements so they never hit it — but the app
            // does, via the `-DODUseInMemoryStore` UI-test hook in
            // `AppDependencies`. Mirrors `makeProductionConfiguration()`'s
            // explicit `.none` opt-out for the same reason.
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
