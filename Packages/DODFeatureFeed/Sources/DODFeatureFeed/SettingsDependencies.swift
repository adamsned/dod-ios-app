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

    /// Writes the CloudKit sync opt-in flag and rebuilds the production
    /// `ModelContainer` so the next open observes the new configuration.
    /// **Order matters** — the flag is written before the rebuild so
    /// the rebuild sees the new value (per T-702's
    /// `recreateContainerAfterOptInChange()` contract).
    func setCloudSyncOptIn(_ enabled: Bool) async

    /// Reads the current opt-in flag value. Provided as a synchronous
    /// read so the view-model's initial state can mirror whatever the
    /// flag is at construction (the user may have flipped it via
    /// T-704's first-launch sheet before ever opening Settings).
    func cloudSyncOptInValue() -> Bool
}
