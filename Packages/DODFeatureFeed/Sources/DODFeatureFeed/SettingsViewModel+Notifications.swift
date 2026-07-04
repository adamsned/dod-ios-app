import Foundation

// US-42 / AC-42.1 + T-750 / CL-147 (DUT-56) — the notification toggle
// setters, extracted from `SettingsViewModel.swift` so that file stays
// under the SwiftLint 400-line file_length cap (the same partitioning
// rule `SettingsViewModel+CloudSync.swift` / `+Voice.swift` / `+Temperature.swift`
// follow). Both setters mutate `internal`-widened members of the host
// (`requestNotificationAuthorization`, `snackbarMessage`) — the access
// modifiers were relaxed from `private` precisely so this sibling-file
// extension can reach them.
//
// Spec trace: US-36 AC-36.1; US-42 AC-42.1; CL-147.

extension SettingsViewModel {

    /// Drives the "When New Recipes Drop" toggle's ON/OFF transition.
    /// Turning **ON** requests system authorization (AC-42.1): on grant
    /// the flag persists `true`; on deny the flag stays `false` (the
    /// toggle reverts) and a snackbar points the user at iOS Settings.
    /// Turning **OFF** simply persists `false` — no system call. Returns
    /// the resolved on/off state so the view's binding can reflect a
    /// denied prompt without a separate observation hop.
    @discardableResult
    public func setNotificationsEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else {
            notificationsEnabled = false
            // DUT-379: "off ⇒ silence" — cancel every future-dated local
            // notification (the guided-cookout bake alerts) so a bake timer started
            // while notifications were ON doesn't still fire after the user opts
            // out. DUT-547: bake alerts are now per-recipe, so flush ALL of them
            // (a shared engine can have several rungs' bakes queued), not just one.
            // New post + bake alerts are already gated on the toggle at schedule
            // time, so these are the only queued requests to flush.
            await SystemBakeTimerNotifier().cancelAllBakeDone()
            return false
        }
        let granted = await requestNotificationAuthorization()
        notificationsEnabled = granted
        if !granted {
            // Persisted intent stays OFF so the UI never claims notifications
            // are on while the OS suppresses them (AC-42.1).
            snackbarMessage = "Enable notifications in iOS Settings → DOD to get new-post alerts."
        }
        return granted
    }

    /// T-750 / CL-147 (DUT-56) — drives the "When Someone Replies to My
    /// Comment" toggle. Mirrors ``setNotificationsEnabled(_:)``: ON
    /// requests authorization (persist on grant, revert + snackbar on
    /// deny); OFF persists `false`. Reply-alert delivery awaits a future
    /// server-side push trigger (the DUT-15 backend gap).
    @discardableResult
    public func setCommentReplyNotificationsEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else {
            commentReplyNotificationsEnabled = false
            return false
        }
        let granted = await requestNotificationAuthorization()
        commentReplyNotificationsEnabled = granted
        if !granted {
            snackbarMessage = "Enable notifications in iOS Settings → DOD to get reply alerts."
        }
        return granted
    }
}
