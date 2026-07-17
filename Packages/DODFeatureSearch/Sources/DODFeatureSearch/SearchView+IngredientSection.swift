import DODDesignSystem
import DODDomain
import SwiftUI

/// DUT-11: the scrolling results body for ``SearchView``'s `.results` state —
/// the existing title/category tier plus the labeled "Recipes using <term>"
/// ingredient tier beneath it. Split out of `SearchView.swift` so that file
/// stays under SwiftLint's 400-line `file_length` cap, matching the
/// `SearchViewModel+T637` / `+T643` extension-split pattern used elsewhere in
/// this feature.
///
/// The ingredient tier renders only when `viewModel.ingredientItems` is
/// non-empty — i.e. when the query matched recipes that USE the term (in
/// their cached ingredient list) and weren't already surfaced by title or
/// category match. It uses the same gallery/list layout toggle as the title
/// tier so the two sections read as one continuous, consistent result list.
/// The header text ("Recipes using …") is what tells the user why a
/// title-less recipe matched — the explicit DUT-11 requirement.
extension SearchView {

    /// The full `.results` scroll view: title tier, then (when present) the
    /// labeled ingredient tier. `layout` is resolved by the caller from the
    /// shared `@AppStorage` layout preference.
    @ViewBuilder
    func resultsScroll(layout: RecipeListLayout) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DODSpacing.lg) {
                Group {
                    switch layout {
                    case .gallery:
                        galleryResults
                    case .list:
                        listResults
                    }
                }
                if !viewModel.ingredientItems.isEmpty {
                    ingredientSection(layout: layout)
                }
            }
            .padding(.horizontal, DODSpacing.md)
            .padding(.bottom, DODSpacing.lg)
        }
    }

    /// The labeled "Recipes using <term>" section: header + the ingredient
    /// hits in the active layout. The header quotes the user's trimmed query
    /// so it always matches what they typed.
    @ViewBuilder
    private func ingredientSection(layout: RecipeListLayout) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            Text("Recipes Using \u{201C}\(ingredientSectionTerm)\u{201D}")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("dod.search.ingredientSection.header")
            switch layout {
            case .gallery:
                ingredientGallery
            case .list:
                ingredientList
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// The query term shown in the header. Trimmed so leading/trailing
    /// whitespace never leaks into the quoted label; falls back to the raw
    /// query if (impossibly) the trim is empty.
    private var ingredientSectionTerm: String {
        let trimmed = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? viewModel.query : trimmed
    }

    /// Ingredient hits in the 2-column gallery layout. Mirrors the title
    /// tier's `galleryResults` card + tap + context-menu wiring so saving /
    /// opening an ingredient hit behaves identically to a title hit; only the
    /// accessibility identifier differs so tests can target the tier.
    private var ingredientGallery: some View {
        LazyVGrid(
            columns: recipeGridColumns(horizontalSizeClass: horizontalSizeClass),
            spacing: DODSpacing.md
        ) {
            ForEach(viewModel.ingredientItems) { item in
                // CL-255 — cook-time chip omitted (browse declutter).
                RecipeCard(
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage
                )
                .recipeCardTap { onSelect(item) }
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
                .accessibilityIdentifier("dod.search.ingredientCard")
            }
        }
    }

    /// Ingredient hits in the dense single-column list layout.
    private var ingredientList: some View {
        // T-782 / DUT-88 — same iPad multi-column tiling as the title tier.
        adaptiveListRows(horizontalSizeClass: horizontalSizeClass) {
            ForEach(viewModel.ingredientItems) { item in
                // CL-255 — cook-time chip omitted (browse declutter).
                RecipeCard.ListRow(
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage
                )
                .recipeCardTap { onSelect(item) }
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
                .accessibilityIdentifier("dod.search.ingredientCard")
            }
        }
    }

    /// US-38 / AC-38.3 — the title tier's 2-col grid. Body byte-identical to the
    /// pre-T-650 `.results` rendering. Moved here from `SearchView.swift`
    /// (file-length relief for the v2 Surprise Me wiring); `resultsScroll`
    /// composes it. `internal` so the shared body can reach it.
    var galleryResults: some View {
        LazyVGrid(
            columns: recipeGridColumns(horizontalSizeClass: horizontalSizeClass),
            spacing: DODSpacing.md
        ) {
            ForEach(viewModel.items) { item in
                // CL-255 — cook-time chip omitted (browse declutter); Search's
                // time filter covers cook time for those who want it.
                RecipeCard(
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage,
                    // Highlight the COMMITTED query (`lastQuery`), not the live
                    // `query` keystroke: the debounced fetch leaves stale cards
                    // on screen, so the live term re-highlighted every card each
                    // keystroke over the wrong substring ("chick" vs "chic").
                    highlightQuery: viewModel.lastQuery
                )
                .recipeCardTap { onSelect(item) }
                .recipeCardContextMenu(
                    isSaved: viewModel.savedRecipeIDs.contains(item.id),
                    onToggle: {
                        // DUT-629 — optimistic flip, re-inverted on write failure.
                        viewModel.applyOptimisticSaveToggle(id: item.id)
                        onSave?(item) { didSave in
                            if !didSave { viewModel.revertOptimisticSaveToggle(id: item.id) }
                        }
                    },
                    // DUT-534 Part 2 — Search opts into the shared helper's
                    // "Add to Shopping List" item (Categories/Saved don't).
                    onAddToShoppingList: { Task { await viewModel.addToShoppingList(item) } }
                )
                // T-737 / L5: stable handle mirroring `dod.feed.card`.
                .accessibilityIdentifier("dod.search.card")
            }
        }
    }

    /// US-38 / AC-38.4 — the title tier's dense single-column variant. Composes
    /// the same tap + context-menu modifiers as the gallery so US-34 / AC-34.1 /
    /// AC-34.6 long-press-Save/Unsave works identically. Moved here alongside
    /// `galleryResults` (file-length relief).
    var listResults: some View {
        // T-782 / DUT-88 — iPad tiles the rows into a multi-column grid; iPhone
        // keeps the single-column LazyVStack.
        adaptiveListRows(horizontalSizeClass: horizontalSizeClass) {
            ForEach(viewModel.items) { item in
                // CL-255 — cook-time chip omitted (browse declutter); Search's
                // time filter covers cook time for those who want it.
                RecipeCard.ListRow(
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage,
                    // Committed query — see the gallery call site's rationale.
                    highlightQuery: viewModel.lastQuery
                )
                .recipeCardTap { onSelect(item) }
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
                .accessibilityIdentifier("dod.search.card")
            }
        }
    }
}
