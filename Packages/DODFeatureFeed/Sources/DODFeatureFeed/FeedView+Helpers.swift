import DODDomain
import DODSupport
import SwiftUI

/// `FeedView` helpers extracted from `FeedView.swift` so both stay under
/// SwiftLint's `file_length` / `type_body_length` caps (DUT-527).
extension FeedView {
    /// CL-273 — the Cooking Journal sheet: loads the logged cooks and wires the
    /// per-entry reflection/photo save (`updateCook`, which never changes the
    /// cook count, so it can't affect rank).
    var cookJournalSheet: some View {
        CookJournalView(
            load: { await viewModel.cookLogs() },
            update: { await viewModel.updateCook($0) },
            delete: { await viewModel.deleteCook($0) }  // DUT-514
        )
    }

    /// Log a completed cook then re-derive the current rung.
    func logCookAndRefresh(_ entry: CookLogEntry) {
        Task {
            await viewModel.logCook(entry)
            await refreshCurrentRung()
        }
    }

    /// DUT-527 — pull-to-refresh, then announce completion. Keeps the
    /// `.refreshable` call site in `FeedView` a one-liner (struct-body cap).
    func refreshAndAnnounce() async {
        await viewModel.refresh()
        announceRefreshResult()
    }

    /// DUT-527 — VoiceOver announcement for a completed pull-to-refresh. Speaks
    /// the offline/error state or the fresh recipe count so a VoiceOver user gets
    /// the same "it finished" confirmation the spinner + success haptic give
    /// sighted users. A no-op when VoiceOver isn't running.
    private func announceRefreshResult() {
        let message: String
        if viewModel.isOffline {
            message = "Couldn't refresh. You're offline."
        } else if viewModel.errorMessage != nil {
            message = "Couldn't refresh recipes."
        } else {
            let count = viewModel.items.count
            message = "Recipes refreshed. \(count) \(count == 1 ? "recipe" : "recipes")."
        }
        AccessibilityNotification.Announcement(message).post()
    }
}
