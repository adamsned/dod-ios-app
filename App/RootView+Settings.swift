import DODDomain
import DODFeatureFeed
import DODNetworking
import SwiftUI

/// T-912 / DUT-551 (CL-306) Settings sheet content + the DUT-941 owner-only
/// test-notification wiring, split out of `RootView.swift` so that host file
/// stays under the SwiftLint `file_length` cap.
extension RootView {

    /// The Settings sheet's content, presented from `RootView.body`'s
    /// `.sheet(isPresented: $showSettingsSheet)`.
    var settingsSheet: some View {
        NavigationStack {
            SettingsView(
                viewModel: dependencies.settingsSheetViewModel(
                    accountTeardownExtras: accountTeardownExtras
                ),
                onClearImageCache: { try await dependencies.store.clearImageCache() },
                // DUT-572 — hide the Profile row on iPad. This reads RootView's
                // TRUE device size class (the same signal that selects iPadSplit
                // vs phoneTabs); the sheet itself always reports `.compact`, so
                // the flag must be resolved here and injected.
                hidesProfile: horizontalSizeClass == .regular,
                // DUT-941 — owner-only "Send Test New-Post Notification" button
                // in Daddy's Tools. `SettingsView` threads this down through
                // `ProfileSettingsSection` to `OwnerToolsPlaceholderView`, which
                // only renders the button when it's non-nil (it always is here;
                // the button itself is hidden for non-owners upstream).
                sendTestNotification: { await sendOwnerTestNotification() }
            )
        }
    }

    /// DUT-941 — fires a REAL local notification for the latest WordPress post
    /// so the owner can verify the whole delivery + `dod://` deep-link chain
    /// on a TestFlight build, which can't trigger the DUT-938 background poll
    /// on demand.
    ///
    /// Deliberately bypasses `NewPostsPoller`'s last-seen diff (it always
    /// fires for the latest post, even if already notified about) but reuses
    /// the SAME `WPRestClient.posts()` call the Feed + poller make (no new
    /// HTTP client) and the SAME `NotificationService.scheduleNewPostNotification`
    /// entry point, so the toggle + system-authorization gate that guards real
    /// delivery still applies — this proves the real path, not a fake one.
    /// Best-effort: a fetch failure does nothing (no notification, no crash).
    func sendOwnerTestNotification() async {
        guard let latest = try? await dependencies.restClient.posts().first else { return }
        await dependencies.notificationService.scheduleNewPostNotification(
            title: latest.title,
            postKind: .recipe,
            recipeID: latest.id
        )
    }
}
