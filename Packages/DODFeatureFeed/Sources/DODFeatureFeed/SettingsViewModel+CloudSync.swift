import DODPersistence
import Foundation

/// US-41 / AC-41.3 iCloud Sync toggle actions.
///
/// Extracted from `SettingsViewModel.swift` for file_length hygiene. The
/// stored `isCloudSyncEnabled` flag + the constructor stay in the main
/// file (Swift requires stored properties on the primary declaration);
/// the toggle action (``setCloudSyncEnabled(_:)``) + status refresh live
/// here. T-759 / CL-156 removed the CL-89 per-toggle confirmation flow
/// (`requestCloudSyncOptIn` / `confirmCloudSyncFlip` / `cancelCloudSyncFlip`
/// + the `CloudSyncConfirmationRequest` type) — the toggle now flips directly.
///
/// Spec trace: US-41 AC-41.3; CL-156 (direct flip, supersedes CL-89).
extension SettingsViewModel {

    /// T-759 / CL-156 (DUT-65) — flip iCloud Sync directly from the toggle,
    /// with NO confirmation popup (the CL-89 per-toggle confirmation +
    /// CL-154's custom dialog are removed — toggling is non-destructive and
    /// deferred to next launch, and the one-time first-launch opt-in sheet
    /// remains the informed-consent moment). Flips the cached flag
    /// synchronously (so the `Toggle` stays in its new position), marks the
    /// relaunch-pending sublabel (SwiftData rebuilds the container only at
    /// next cold launch — round-12 backlog note), and persists the canonical
    /// opt-in flag via the dependency (which triggers the T-702 container-
    /// rebuild seam). No-op when unchanged. Returns the persistence `Task`
    /// so tests can await the dependency write; production discards it.
    @discardableResult
    public func setCloudSyncEnabled(_ enabled: Bool) -> Task<Void, Never>? {
        guard enabled != isCloudSyncEnabled else { return nil }
        isCloudSyncEnabled = enabled
        cloudSyncPendingRelaunch = true
        guard let dependency = cloudSyncDependency else { return nil }
        return Task { await dependency.setCloudSyncOptIn(enabled) }
    }

    /// Pull the latest coarse sync status from the dependency (the
    /// App-target CloudKit mirror observer) into ``cloudSyncStatus`` so the
    /// status sublabel reflects idle / syncing / error (DUT-6, cause B).
    /// Called when the Settings screen appears. A no-op when no dependency
    /// is wired (previews / snapshot hosts) — the default `.off` stays,
    /// rendering the reserved "Idle" placeholder. Skipped while a flip is
    /// pending relaunch, since the live status is meaningless until the
    /// container is rebuilt at next launch (the relaunch copy wins anyway).
    public func refreshCloudSyncStatus() {
        guard !cloudSyncPendingRelaunch, let dependency = cloudSyncDependency else { return }
        updateCloudSyncStatus(dependency.currentCloudSyncStatus())
    }
}
