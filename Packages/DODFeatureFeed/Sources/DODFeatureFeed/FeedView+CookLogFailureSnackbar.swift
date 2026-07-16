import DODDesignSystem
import SwiftUI

// PR #746 — extracted out of `FeedView+FirstCookoutHero.swift` when that file
// was deleted (the top-of-feed hero card it hosted was replaced by a slim
// tab-bar callout, `RootView+FirstCookoutCallout.swift`). This snackbar is
// unrelated to the hero card itself — it survives that removal.

extension FeedView {

    /// The cook-log failure snackbar — surfaces when `FeedViewModel.logCook`'s
    /// store write fails. The guided cookout sheet has already dismissed by the
    /// time this write resolves (`CookingToolsHubView` fires it fire-and-forget
    /// after "Done"), so the Feed — the screen the user lands back on — is where
    /// this has to show. Mirrors `shoppingListSnackbar`'s auto-dismiss pattern
    /// (DUT-534 Part 2).
    @ViewBuilder
    var cookLogFailureSnackbar: some View {
        if let message = viewModel.cookLogFailureMessage {
            Snackbar(message: message)
                .id(message)  // a new message restarts the auto-dismiss timer
                .padding(.bottom, DODSpacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    viewModel.dismissCookLogFailureMessage()
                }
        }
    }
}
