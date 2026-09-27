import Foundation

// DUT-162 — the "Export My Data" action, split out of `SettingsViewModel.swift`
// to keep that file under the SwiftLint 400-line `file_length` cap (the same
// partitioning rule the CloudSync / Voice / Notifications splits follow).
extension SettingsViewModel {

    /// Run the export through the injected ``SettingsDependencies`` seam and
    /// return the generated file's URL for the share sheet, or `nil` when no
    /// seam is wired (previews / the L1 double) or the gather fails. A failure
    /// surfaces a humane snackbar so the tap is never a silent no-op.
    ///
    /// The gather itself is offline and account-free (all sources are local),
    /// so this succeeds for guest users with no network connection.
    public func exportMyData() async -> URL? {
        guard let cloudSyncDependency else { return nil }
        do {
            return try await cloudSyncDependency.exportMyData()
        } catch {
            snackbarMessage = "Couldn't export your data. Please try again."
            return nil
        }
    }
}
