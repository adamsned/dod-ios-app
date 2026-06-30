import DODPersistence
import DODSupport
import Foundation

/// Narrow surface the Settings page needs from external modules for
/// state that lives outside the view-model's UserDefaults round-trip.
///
/// Today the only consumer is the iCloud Sync row (US-41 / AC-41.3) —
/// the Settings page needs a seam that **(1)** writes the
/// `RecipeStore.cloudKitSyncOptInKey` flag and **(2)** triggers the
/// `RecipeStore.recreateContainerAfterOptInChange()` rebuild so the
/// next `ModelContainer` open reads the freshly-flipped flag and
/// constructs the right `ModelConfiguration` (CloudKit-backed when
/// opt-in is ON, plain SwiftData when OFF). The write-then-rebuild
/// order is load-bearing: the flag must land before the rebuild
/// because the rebuild reads the flag at construction time per the
/// T-702 contract.
///
/// **Why a protocol seam instead of reaching into `RecipeStore`
/// directly from the view-model.** `SettingsViewModel` lives in
/// `DODFeatureFeed` which already depends on `DODPersistence`, so the
/// dependency direction is allowed; but the view-model is
/// `@MainActor` and the rebuild is a `throws` operation that the
/// composition root is the natural owner of. Routing through this
/// protocol keeps the view-model testable (the L1 suite injects a
/// recording double) and keeps the actual container swap behind the
/// `AppDependencies` boundary where T-704's opt-in sheet and T-705's
/// status surface will land their own writes against the same seam.
///
/// Spec trace: US-41 AC-41.3; CL-89 (the toggle's opt-in contract).
public protocol SettingsDependencies: Sendable {

    /// Persists the CloudKit sync opt-in flag (DUT-6). The flag is the
    /// single source of truth, re-read at the *next* launch by
    /// `RecipeStore.productionContainer(defaults:)` to choose the
    /// CloudKit-backed vs plain container — there is no mid-session
    /// container rebuild (SwiftData can't hot-swap the configuration, and
    /// the running `RecipeStore`/store env aren't re-wired by one). The
    /// view-model surfaces a relaunch-to-apply hint after this returns.
    func setCloudSyncOptIn(_ enabled: Bool) async

    /// Reads the current opt-in flag value. Provided as a synchronous
    /// read so the view-model's initial state can mirror whatever the
    /// flag is at construction (the user may have flipped it via
    /// T-704's first-launch sheet before ever opening Settings).
    func cloudSyncOptInValue() -> Bool

    /// Reads the latest coarse CloudKit sync status (DUT-6, cause B) from
    /// the App-target `NSPersistentCloudKitContainer` mirror observer. The
    /// Settings row pulls this when it appears to refresh its status
    /// sublabel (idle / syncing / error). Defaults to
    /// ``CloudKitSyncStatus/off`` for conformers that don't observe the
    /// mirror (previews, snapshot hosts, the L1 recording double), so
    /// existing call sites stay source-compatible.
    func currentCloudSyncStatus() -> CloudKitSyncStatus

    // MARK: - Profile stats (DUT-417 / CL-292)
    //
    // The Settings ▸ Profile view-mode stats section needs read access to the
    // local cook log, saved-recipe count, and user-rating count, plus the
    // journal's in-place edit. All default to empty so previews / the L1
    // recording double stay source-compatible and render no stats.

    /// All logged cooks (newest first), for the Cook Rank + Total Cooks +
    /// Weekly Streak stats and the "View Cooking Journal" sheet.
    func cookLogs() async throws -> [CookLogEntry]
    /// Number of saved recipes.
    func savedRecipeCount() async throws -> Int
    /// Number of recipes this device has submitted a star rating for.
    func userRatingCount() async throws -> Int
    /// In-place edit of one cook-log entry from the journal (note / rating /
    /// photo); never changes the cook count.
    func updateCookLog(_ entry: CookLogEntry) async throws
}

extension SettingsDependencies {
    public func currentCloudSyncStatus() -> CloudKitSyncStatus { .off }

    public func cookLogs() async throws -> [CookLogEntry] { [] }
    public func savedRecipeCount() async throws -> Int { 0 }
    public func userRatingCount() async throws -> Int { 0 }
    public func updateCookLog(_ entry: CookLogEntry) async throws {}
}
