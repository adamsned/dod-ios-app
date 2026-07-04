import DODDesignSystem
import SwiftUI

// The recipe-detail top-bar actions + the bottom Snackbar, split out of
// `RecipeDetailView.swift` to keep that file under the SwiftLint 400-line
// `file_length` + 250-line `type_body_length` caps (DUT-534 added the
// "Add to Shopping List" action + the Snackbar action seam).

extension RecipeDetailView {

    // MARK: - Toolbars

    @ToolbarContentBuilder
    var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: DODSpacing.md) {
                // Save haptic is wired via `.sensoryFeedback(.success, trigger:
                // viewModel.isSaved)` on the body — no manual generator here.
                Button {
                    Task { await viewModel.toggleSaved() }
                } label: {
                    Image(systemName: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(viewModel.isSaved ? DODColor.accent : DODColor.label)
                }
                .accessibilityLabel(viewModel.isSaved ? "Unsave recipe" : "Save recipe")

                // US-39 / DUT-534 — "Add to Shopping List" from ANY recipe (not
                // just saved). Detail's `recipe` is already loaded, so this
                // appends its ingredients straight to the App-Group list and
                // shows a confirming Snackbar with a "View" action. Sits between
                // Save (AC-4.7) and Download (AC-35.1).
                Button {
                    Task { await viewModel.addToShoppingList() }
                } label: {
                    Image(systemName: "cart.badge.plus")
                        .foregroundStyle(DODColor.label)
                }
                .disabled(viewModel.recipe == nil)
                .accessibilityLabel("Add to Shopping List")
                .accessibilityIdentifier("dod.detail.addToShoppingList")

                // US-35 / AC-35.1 — explicit download for offline use, now a
                // toggle (T-775 / DUT-81, supersedes CL-61's always-outline +
                // "Already downloaded" re-tap snackbar). Downloaded → filled
                // burnt-orange glyph; tapping removes the download. Not
                // downloaded → outline glyph; tapping downloads. Sits between
                // Save (AC-4.7) and Share (AC-4.8).
                Button {
                    Task { await viewModel.toggleDownload() }
                } label: {
                    Image(
                        systemName: viewModel.isDownloaded
                            ? "square.and.arrow.down.fill"
                            : "square.and.arrow.down"
                    )
                    .foregroundStyle(viewModel.isDownloaded ? DODColor.burntOrange : DODColor.label)
                }
                .accessibilityLabel(viewModel.isDownloaded ? "Remove download" : "Download for offline use")

                ShareLink(item: viewModel.canonicalURL) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(DODColor.label)
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        Task { await viewModel.didShare() }
                    }
                )
                .accessibilityLabel("Share recipe")
            }
        }
    }

    // MARK: - Snackbar

    @ViewBuilder
    var snackbar: some View {
        if let message = viewModel.snackbarMessage {
            Snackbar(message: message, action: snackbarAction)
                .id(message)  // DUT-419: a new message restarts the auto-dismiss timer
                .padding(.bottom, DODSpacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    viewModel.dismissSnackbar()
                }
        }
    }

    /// DUT-534 — the optional trailing Snackbar action. Present only when the
    /// view model set ``RecipeDetailViewModel/snackbarActionTitle`` (the
    /// "Add to Shopping List" success toast) AND the host wired
    /// ``openShoppingList``. Tapping it dismisses the toast and routes to the
    /// list.
    private var snackbarAction: Snackbar.Action? {
        guard let title = viewModel.snackbarActionTitle, let openShoppingList else {
            return nil
        }
        return Snackbar.Action(title: title) {
            viewModel.dismissSnackbar()
            openShoppingList()
        }
    }
}
