import DODDesignSystem
import SwiftUI

// DUT-534 Part 2 — the Feed card "Add to Shopping List" confirmation snackbar
// host + the two card-list builders (which now carry the opt-in menu item),
// split out of `FeedView.swift` to keep that file under the SwiftLint 400-line
// `file_length` + 250-line `type_body_length` caps (mirrors Recipe Detail's
// `RecipeDetailView+Toolbar.swift` snackbar split).

extension FeedView {

    /// US-38 / AC-38.3 — the existing 2-col `LazyVGrid` rendering. Body
    /// byte-identical to the pre-T-650 `list` implementation; CC-9's grid
    /// contract is preserved unchanged.
    var galleryContent: some View {
        LazyVGrid(columns: recipeGridColumns(horizontalSizeClass: horizontalSizeClass), spacing: DODSpacing.md) {
            ForEach(viewModel.items) { item in
                FeedRow(item: item)
                    .recipeCardTap { onSelect(item, viewModel.items) }
                    // T-765 / CL-162 (DUT-71) — state-aware Save/Unsave from the
                    // viewmodel-owned saved-id set; optimistic flip on toggle.
                    .recipeCardContextMenu(
                        isSaved: viewModel.savedRecipeIDs.contains(item.id),
                        onToggle: {
                            // DUT-629 — optimistic flip, re-inverted if the store
                            // write reported failure via the completion.
                            viewModel.applyOptimisticSaveToggle(id: item.id)
                            onSave?(item) { didSave in
                                if !didSave { viewModel.revertOptimisticSaveToggle(id: item.id) }
                            }
                        },
                        // DUT-534 Part 2 — Feed opts into the shared helper's
                        // "Add to Shopping List" item (Categories/Saved don't).
                        onAddToShoppingList: { Task { await viewModel.addToShoppingList(item) } }
                    )
                    // Stable L3 handle: `app.buttons.matching(identifier:)`
                    // targets feed recipe cards directly, so XCUITest can't
                    // accidentally tap a nav-bar toolbar button (the layout
                    // toggle / Settings gear) that the old "buttons NOT IN
                    // tab labels" query swept up. Mirrors `dod.saved.card`.
                    // Non-visual — does not affect L4 snapshots.
                    .accessibilityIdentifier("dod.feed.card")
                    .task {
                        await viewModel.loadMoreIfNeeded(currentItem: item)
                    }
            }
        }
    }

    /// US-38 / AC-38.4 — the new denser single-column variant. Composes
    /// the same `recipeCardTap` + `recipeCardContextMenu` modifiers as
    /// the gallery so tap-to-open + long-press-Save/Unsave (AC-34.1 /
    /// AC-34.6) work identically on both layouts.
    var listContent: some View {
        // T-782 / DUT-88 — iPad tiles the dense rows into a multi-column grid;
        // iPhone (compact) keeps the exact single-column LazyVStack.
        adaptiveListRows(horizontalSizeClass: horizontalSizeClass) {
            ForEach(viewModel.items) { item in
                // CL-254 (feed declutter) — no cook-time chip on the Recipes
                // feed (noise); `totalTimeDisplay` omitted (defaults to nil).
                // Time still shows on Search + the recipe detail page.
                RecipeCard.ListRow(
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage
                )
                .recipeCardTap { onSelect(item, viewModel.items) }
                .recipeCardContextMenu(
                    isSaved: viewModel.savedRecipeIDs.contains(item.id),
                    onToggle: {
                        // DUT-629 — optimistic flip, re-inverted on write failure.
                        viewModel.applyOptimisticSaveToggle(id: item.id)
                        onSave?(item) { didSave in
                            if !didSave { viewModel.revertOptimisticSaveToggle(id: item.id) }
                        }
                    },
                    onAddToShoppingList: { Task { await viewModel.addToShoppingList(item) } }
                )
                .accessibilityIdentifier("dod.feed.card")
                .task {
                    await viewModel.loadMoreIfNeeded(currentItem: item)
                }
            }
        }
    }

    /// The bottom "Add to Shopping List" confirmation snackbar. Present only
    /// while the view model set a message; a `.task` auto-dismisses it after a
    /// few seconds (mirrors Recipe Detail's Part 1 snackbar, DUT-419).
    @ViewBuilder
    var shoppingListSnackbar: some View {
        if let message = viewModel.shoppingListSnackbarMessage {
            Snackbar(message: message, action: shoppingListSnackbarAction)
                .id(message)  // a new message restarts the auto-dismiss timer
                .padding(.bottom, DODSpacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    viewModel.dismissShoppingListSnackbar()
                }
        }
    }

    /// The optional trailing snackbar action. Present only on a successful
    /// append (the view model set a title) AND when the host wired
    /// `openShoppingList`. Tapping it dismisses the toast and opens the list.
    private var shoppingListSnackbarAction: Snackbar.Action? {
        guard let title = viewModel.shoppingListSnackbarActionTitle,
            let openShoppingList
        else { return nil }
        return Snackbar.Action(title: title) {
            viewModel.dismissShoppingListSnackbar()
            openShoppingList()
        }
    }
}
