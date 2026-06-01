import DODPersistence
import Foundation

/// US-41 / AC-41.3 iCloud Sync toggle actions.
///
/// Extracted from `SettingsViewModel.swift` so that file stays under the
/// SwiftLint 400-line file_length cap. The split mirrors how
/// `RecipeStore + RecipeStore+Containers.swift` carved the persistence
/// surface — same type, same access boundary, different file for cap
/// hygiene. The stored properties (``SettingsViewModel/isCloudSyncEnabled``,
/// ``SettingsViewModel/cloudSyncConfirmationRequest``) and the constructor
/// stay in the main file because Swift requires stored properties on the
/// primary declaration; the action methods + the
/// ``CloudSyncConfirmationRequest`` value type live here.
///
/// Spec trace: US-41 AC-41.3; CL-89 (confirmation alert flow).
extension SettingsViewModel {

    /// Entry point for a toggle flip — never writes the flag directly,
    /// always defers to the confirmation alert (per CL-89's "no silent
    /// opt-in" contract). The view binds the toggle's `Binding<Bool>`
    /// to a closure that calls this; the toggle's UI state still flips
    /// optimistically because SwiftUI's `Toggle` updates its own
    /// rendering before the binding setter returns. ``cancelCloudSyncFlip()``
    /// undoes that optimistic flip when the alert is cancelled.
    public func requestCloudSyncOptIn(_ enable: Bool) {
        // The view-layer Binding flipped the toggle's visible state to
        // `enable` already. Stash a request so the view renders the
        // matching alert; the user's response routes through
        // ``confirmCloudSyncFlip()`` or ``cancelCloudSyncFlip()``.
        cloudSyncConfirmationRequest = CloudSyncConfirmationRequest(targetEnabled: enable)
    }

    /// Confirms the pending flip — writes the flag via the dependency
    /// (which also triggers the container rebuild per the T-702 seam)
    /// and clears the alert state. Called by the alert's primary
    /// button. If no dependency was injected (preview / snapshot host),
    /// the alert still dismisses and the view-model's cached flag
    /// mirrors the requested value so the surface stays internally
    /// consistent.
    public func confirmCloudSyncFlip() async {
        guard let request = cloudSyncConfirmationRequest else { return }
        cloudSyncConfirmationRequest = nil
        if let dependency = cloudSyncDependency {
            await dependency.setCloudSyncOptIn(request.targetEnabled)
        }
        isCloudSyncEnabled = request.targetEnabled
        // SwiftData can't swap the container mid-process, so the new on/off
        // state only engages on the next cold launch — surface that so a
        // silent flip doesn't read as "sync is broken" (round-12 backlog bug).
        cloudSyncPendingRelaunch = true
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

    /// Cancels the pending flip — reverts the cached toggle state to
    /// the pre-request value (so the optimistic flip the SwiftUI
    /// `Toggle` performed gets undone on the next read) and clears the
    /// alert state. The persisted flag is never touched.
    public func cancelCloudSyncFlip() {
        // The request's `targetEnabled` is the value the user *would*
        // have moved to; reverting means snapping back to the inverse.
        if let request = cloudSyncConfirmationRequest {
            isCloudSyncEnabled = !request.targetEnabled
        }
        cloudSyncConfirmationRequest = nil
    }
}

// MARK: - iCloud Sync confirmation alert payload (AC-41.3)

/// Describes a pending iCloud Sync toggle flip awaiting the user's
/// confirmation alert response. `targetEnabled` is the value the user
/// would land on if they confirm — `true` means an off → on flip (the
/// "Turn on iCloud Sync?" alert renders), `false` means an on → off
/// flip (the "Turn off iCloud Sync?" alert renders).
///
/// Per CL-89 every flip requires confirmation: enabling so the user
/// understands what data will leave the device, disabling so the user
/// understands what stays + what stops being written. The view layer
/// reads `targetEnabled` to pick which alert copy to show.
///
/// Spec trace: US-41 AC-41.3; CL-89 (opt-in flow).
public struct CloudSyncConfirmationRequest: Sendable, Equatable {
    public let targetEnabled: Bool

    public init(targetEnabled: Bool) {
        self.targetEnabled = targetEnabled
    }
}
