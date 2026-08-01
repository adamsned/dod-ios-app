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
                        // DUT-1322 — circular scrim (replaces the old bare
                        // `.foregroundStyle` + `.shadow`) so the glyph reads over
                        // BOTH the full-bleed hero photo AND the plain
                        // `DODColor.surface` once scrolled past it. See
                        // `ToolbarGlyphChip.swift` for the contrast math.
                        .toolbarGlyphChip(foreground: ToolbarGlyphForeground.save(isSaved: viewModel.isSaved))
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
                        // DUT-1322 — see the Save button above.
                        .toolbarGlyphChip(foreground: ToolbarGlyphForeground.neutral)
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
                    // DUT-1322 — see the Save button above.
                    .toolbarGlyphChip(
                        foreground: ToolbarGlyphForeground.download(isDownloaded: viewModel.isDownloaded)
                    )
                }
                .accessibilityLabel(viewModel.isDownloaded ? "Remove download" : "Download for offline use")

                // Tapping Share opens Apple's full share sheet directly (was a
                // `Menu` offering "Share Link" / "Share as Text"). One tap now
                // presents the system sheet carrying the formatted recipe —
                // title, ingredients, numbered steps, and the canonical URL — so
                // the user can Print the instructions, or send the whole recipe
                // to any contact or service (Messages, Mail, Notes, third-party
                // apps), with the link included. The payload stays the SCALED
                // (+ metric-converted) text (DUT-639), matching what's on screen.
                // Before the recipe finishes loading (rare, transient) it falls
                // back to the URL alone. The `simultaneousGesture` keeps the
                // share haptic (via the body's `.sensoryFeedback` on
                // `shareTapCount`) + `didShare()` telemetry firing on tap.
                // v1/v2 parity: the identical behavior change lands on v2.
                ShareLink(item: recipeShareText) {
                    Image(systemName: "square.and.arrow.up")
                        // DUT-1322 — see the Save button above.
                        .toolbarGlyphChip(foreground: ToolbarGlyphForeground.neutral)
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        shareTapCount += 1
                        Task { await viewModel.didShare() }
                    }
                )
                .accessibilityLabel("Share recipe")
            }
        }
    }

    // MARK: - Share payload

    /// The single item handed to the full Share sheet. Once the recipe is loaded
    /// this is the SCALED (+ metric-converted) formatted recipe — title,
    /// ingredients, numbered steps, canonical URL — so Print carries the
    /// instructions and any messaging / service target gets the whole recipe plus
    /// the link, matching what's on screen. Before load (rare, transient) it
    /// falls back to the canonical URL string so Share still works.
    var recipeShareText: String {
        if let recipe = viewModel.recipe {
            return Self.shareAsTextPayload(
                recipe: recipe,
                servingsScaleFactor: viewModel.servingsScaleFactor,
                useMetricUnits: useMetricUnits
            )
        }
        return viewModel.canonicalURL.absoluteString
    }

    /// Build the shared payload: the recipe rewritten through the same SCALED
    /// (+ metric-converted when `useMetricUnits` is on) ingredient pipeline the
    /// ingredients list, Cook Mode, and "Add to Shopping List" already share
    /// (DUT-639), so what gets shared matches what's on screen rather than the
    /// recipe's raw source-servings / imperial text.
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
