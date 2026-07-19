import DODDesignSystem
import DODDomain
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
                        // DUT-572 / CL-312 — glyph shadow so state colors survive
                        // over the full-bleed hero photo (mirrors the title shadow).
                        .shadow(color: .black.opacity(0.35), radius: 3)
                }
                .accessibilityLabel(viewModel.isSaved ? "Unsave recipe" : "Save recipe")

                // US-39 / DUT-534 / DUT-535 — "Add to Shopping List" from ANY
                // recipe (not just saved). DUT-535: tapping now PRESENTS the
                // ingredient-selection sheet (pick which ingredients to add)
                // rather than adding all immediately. Detail's `recipe` is
                // already loaded (ingredients populated), so no hydration is
                // needed. When the sheet seam isn't wired (previews / terse
                // hosts) it falls back to DUT-534's immediate add-all. Sits
                // between Save (AC-4.7) and Download (AC-35.1).
                Button {
                    presentAddToShoppingList()
                } label: {
                    Image(systemName: "cart.badge.plus")
                        .foregroundStyle(DODColor.label)
                        .shadow(color: .black.opacity(0.35), radius: 3)
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
                    .shadow(color: .black.opacity(0.35), radius: 3)
                }
                .accessibilityLabel(viewModel.isDownloaded ? "Remove download" : "Download for offline use")

                // DUT-889 — iOS parity twin of Android's DUT-886 "Share as
                // Text". A bare `ShareLink` can only carry one payload, so
                // the URL-only share (unchanged behavior) and the new
                // formatted plain-text share now live behind a `Menu` on
                // the same toolbar glyph rather than adding a 6th icon.
                // Each option gets its own `simultaneousGesture` so the
                // haptic + `didShare()` telemetry still fires regardless of
                // which format the user picked.
                Menu {
                    ShareLink(item: viewModel.canonicalURL) {
                        Label("Share Link", systemImage: "link")
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            shareTapCount += 1  // fires the `.sensoryFeedback` tick on the body
                            Task { await viewModel.didShare() }
                        }
                    )

                    if let recipe = viewModel.recipe {
                        // Fix: share the SCALED (+ metric-converted when "Use
                        // Metric Units" is on) ingredient lines, matching what's
                        // on screen and what "Add to Shopping List" already
                        // shares (DUT-639) — not the raw source-servings /
                        // imperial text the recipe was fetched with.
                        ShareLink(
                            item: Self.shareAsTextPayload(
                                recipe: recipe,
                                servingsScaleFactor: viewModel.servingsScaleFactor,
                                useMetricUnits: useMetricUnits
                            )
                        ) {
                            Label("Share as Text", systemImage: "doc.plaintext")
                        }
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                shareTapCount += 1
                                Task { await viewModel.didShare() }
                            }
                        )
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(DODColor.label)
                        .shadow(color: .black.opacity(0.35), radius: 3)
                }
                .accessibilityLabel("Share recipe")
            }
        }
    }

    // MARK: - Share as Text

    /// Build the "Share as Text" payload: the recipe rewritten through the
    /// same SCALED (+ metric-converted when `useMetricUnits` is on) ingredient
    /// pipeline the ingredients list, Cook Mode, and "Add to Shopping List"
    /// already share (DUT-639), so what gets shared matches what's on screen
    /// rather than the recipe's raw source-servings / imperial text.
    ///
    /// `static` and free of view state so it's directly unit-testable without
    /// standing up a live `RecipeDetailView` hierarchy.
    static func shareAsTextPayload(
        recipe: Recipe,
        servingsScaleFactor: Double,
        useMetricUnits: Bool
    ) -> String {
        let scaled = RecipeDetailViewModel.scaledRecipe(
            recipe,
            by: servingsScaleFactor,
            useMetric: useMetricUnits
        )
        return RecipeShareTextFormatter.format(recipe: scaled)
    }

    // MARK: - Add to Shopping List (DUT-535)

    /// Handle the `cart.badge.plus` tap. DUT-535 — present the ingredient-
    /// selection sheet for the loaded recipe when the sheet seam is wired
    /// (production). When it isn't (previews / terse hosts that only wired the
    /// DUT-534 immediate-add closure), fall back to the immediate add-all so the
    /// action still works. Guarded on `recipe != nil` (the button is disabled
    /// when nil, but guard defensively).
    private func presentAddToShoppingList() {
        guard let recipe = viewModel.recipe else { return }
        if addToShoppingListSheet != nil {
            // DUT-639 — hand the selection sheet the SCALED (+ metric-converted)
            // recipe so the chosen rows match the displayed ingredient lines.
            let scaled = RecipeDetailViewModel.scaledRecipe(
                recipe,
                by: viewModel.servingsScaleFactor,
                useMetric: useMetricUnits
            )
            recipeForShoppingListSheet = SheetRecipe(recipe: scaled)
        } else {
            Task { await viewModel.addToShoppingList(useMetric: useMetricUnits) }
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
