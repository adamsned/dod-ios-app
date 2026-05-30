import DODDesignSystem
import DODDomain
import SwiftUI

public struct SearchView: View {

    @State private var viewModel: SearchViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// US-38 / AC-38.2 / CL-64 (T-650, 2026-05-27) — shared with `FeedView`
    /// via the same `@AppStorage` key. Default `.gallery` preserves the
    /// existing search-results 2-column grid byte-for-byte.
    @AppStorage(RecipeListLayout.storageKey) private var layoutRaw: String =
        RecipeListLayout.gallery.rawValue
    public let onSelect: (RecipeListItem) -> Void
    /// US-34 / AC-34.1 — long-press → "Save" context menu wiring. See
    /// `FeedView.onSave` for the contract; same shape applied to search hits.
    public let onSave: ((RecipeListItem) -> Void)?

    public init(
        viewModel: SearchViewModel,
        onSelect: @escaping (RecipeListItem) -> Void,
        onSave: ((RecipeListItem) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
        self.onSave = onSave
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchField
            FilterChipRow(filters: $viewModel.filters)
            content
        }
        .background(DODColor.surface)
        .navigationTitle("Search")
        .toolbar {
            // US-38 / AC-38.1 (T-650): layout toggle on the trailing
            // edge of the Search-tab nav bar. Same `topBarTrailing`
            // placement as `FeedView`'s toggle, so a user who learns
            // the affordance on one tab finds it in the same spot on
            // the other. `#if os(iOS)` mirror of the FeedView pattern.
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                layoutToggleToolbarButton
            }
            #else
            ToolbarItem(placement: .automatic) {
                layoutToggleToolbarButton
            }
            #endif
        }
        .task { await viewModel.loadCategoriesIfNeeded() }
    }

    /// US-38 / AC-38.1 / CL-64 (T-650): the layout-toggle button. Same
    /// shape as `FeedView.layoutToggleToolbarButton` — current-state
    /// icon convention (CL-64.1), destination-aware accessibility hint.
    private var layoutToggleToolbarButton: some View {
        let layout = RecipeListLayout(rawValue: layoutRaw) ?? .gallery
        return Button {
            var next = layout
            next.toggle()
            layoutRaw = next.rawValue
        } label: {
            Image(systemName: layout.toggleIconName)
                .accessibilityLabel(layout.currentStateAccessibilityLabel)
                .accessibilityHint(layout.destinationActionHint)
        }
        .accessibilityIdentifier("search-toolbar-layout-toggle")
    }

    private var searchField: some View {
        HStack(spacing: DODSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DODColor.labelSecondary)
            TextField("Search recipes", text: $viewModel.query)
                .autocorrectionDisabled()
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DODColor.labelSecondary)
                }
                .accessibilityLabel("Clear")
            }
        }
        .padding(DODSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .padding(DODSpacing.md)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            IdleSuggestionsView(
                recents: viewModel.recentSearches,
                topCategories: viewModel.topCategorySuggestions,
                onRecentTap: { viewModel.selectRecent($0) },
                // US-29 / AC-29.1 / CL-49.1 + CL-49.5: tapping a "Try"
                // category pill populates the search field and runs a
                // normal text query through the existing debounce path.
                // The pre-T-500 path also set `filters.categoryID`, which
                // dropped every REST result whose recipe-detail page
                // hadn't yet hydrated the local category-IDs cache — the
                // smoking gun behind the "tag search returns no results"
                // round-6 report. CL-49 documents the full root cause.
                //
                // REG-19 / CL-66 / T-670: route through
                // `selectCuratedSuggestion(_:)` (not raw `query = ...`)
                // so the resulting REST search does NOT persist the
                // tapped category name into the recent-searches store.
                // The user tapped a curated pill; they did not type the
                // term. Persisting it makes Clear All look broken because
                // the same curated terms reappear under Recent.
                onCategoryTap: { category in
                    viewModel.selectCuratedSuggestion(category.name)
                },
                onClearRecents: { viewModel.clearRecentSearches() },
                // US-33 / AC-33.3 / CL-57: per-term context-menu Clear.
                onRemoveRecent: { viewModel.removeRecentSearch($0) }
            )
        case .searching:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .noResults:
            // US-29 / AC-29.3 / CL-49.3: glyph swap from
            // `questionmark.folder` to `questionmark.circle`. Explicitly
            // reverses AC-20.3's carve-out — round-6 user feedback was
            // that `questionmark.folder` reads as "in some folder I
            // haven't found" rather than "not found, period."
            // `questionmark.circle` is the iOS-stock "I can't find what
            // you asked for" glyph (Settings' search, Mail's search,
            // Notes' search all use it).
            EmptyState(
                systemImage: "questionmark.circle",
                title: "No recipes match '\(viewModel.query)'",
                message: "Try a different word or clear a filter."
            )
        case .offline:
            EmptyState(
                systemImage: "wifi.slash",
                title: "Search needs internet",
                message: "Reconnect to search dutchovendaddy.com."
            )
        case .results:
            // US-38 / AC-38.3 / AC-38.4 (T-650): branch on the persisted
            // layout. `.gallery` keeps the existing 2-col `LazyVGrid` body
            // byte-identical; `.list` renders `RecipeCard.ListRow` rows.
            let layout = RecipeListLayout(rawValue: layoutRaw) ?? .gallery
            ScrollView {
                Group {
                    switch layout {
                    case .gallery:
                        galleryResults
                    case .list:
                        listResults
                    }
                }
                .padding(.horizontal, DODSpacing.md)
                .padding(.bottom, DODSpacing.lg)
            }
        }
    }

    /// US-38 / AC-38.3 — existing 2-col grid. Body byte-identical to the
    /// pre-T-650 `.results` rendering.
    private var galleryResults: some View {
        LazyVGrid(
            columns: recipeGridColumns(horizontalSizeClass: horizontalSizeClass),
            spacing: DODSpacing.md
        ) {
            ForEach(viewModel.items) { item in
                RecipeCard(
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage,
                    totalTimeDisplay: item.totalTimeDisplay
                )
                .recipeCardTap { onSelect(item) }
                // US-34 / AC-34.6 / CL-103 (T-634, 2026-05-29) — TODO:
                // thread per-card `isSaved` state once a Search
                // viewmodel-owned `Set<Int>` of saved IDs (CL-60 path-(c))
                // is wired. Until then `false` keeps the pre-T-634 "Save"
                // + `bookmark.fill` copy at this surface; the high-value
                // Saved-tab fix is the priority for T-634.
                .recipeCardContextMenu(isSaved: false) { onSave?(item) }
            }
        }
    }

    /// US-38 / AC-38.4 — dense single-column variant. Composes the same
    /// tap + context-menu modifiers as the gallery so US-34 / AC-34.1
    /// / AC-34.6 long-press-Save/Unsave works identically.
    private var listResults: some View {
        LazyVStack(spacing: DODSpacing.xs) {
            ForEach(viewModel.items) { item in
                RecipeCard.ListRow(
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage,
                    totalTimeDisplay: item.totalTimeDisplay
                )
                .recipeCardTap { onSelect(item) }
                // US-34 / AC-34.6 / CL-103 (T-634, 2026-05-29) — TODO as
                // above (CL-60 path-(c) viewmodel-owned saved-IDs set).
                .recipeCardContextMenu(isSaved: false) { onSave?(item) }
            }
        }
    }
}

// MARK: - Filter chips

/// Horizontal row of filter chips above the results list. Each chip flips
/// one slice of `SearchFilters`; mutating the binding triggers
/// `SearchViewModel`'s `reapplyFilters` and the result set re-ranks
/// instantly without a network call (US-12 / AC-12.3).
struct FilterChipRow: View {
    @Binding var filters: SearchFilters

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DODSpacing.xs) {
                cookTimeChip
            }
            .padding(.horizontal, DODSpacing.md)
            .padding(.bottom, DODSpacing.sm)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search filters")
    }

    // US-29 / AC-29.4 / CL-49.4 + CL-105 (T-636): the "All categories"
    // filter chip was removed because the Categories tab (bottom nav)
    // already serves as the canonical "browse all categories" surface,
    // making the chip duplicative. `filters.categoryID` is retained on
    // the model (always nil here → "all categories" pipeline path) so
    // the search merge logic remains untouched; only the UI affordance
    // to mutate it is gone.

    private var cookTimeChip: some View {
        Menu {
            Button("Any time") { filters.cookTime = nil }
            ForEach(CookTimeBucket.allCases) { bucket in
                Button(bucket.label) { filters.cookTime = bucket }
            }
        } label: {
            chipLabel(
                text: filters.cookTime?.label ?? "Any time",
                systemImage: "clock",
                isOn: filters.cookTime != nil
            )
        }
        .accessibilityLabel("Cook time filter, \(filters.cookTime?.label ?? "any time")")
    }

    // US-33 / CL-105 (T-636): the "Recently viewed" toggle chip was
    // removed because the Recent searches section in
    // `IdleSuggestionsView` already surfaces a user's recent activity,
    // making the toggle duplicative. `filters.recentlyViewedOnly` is
    // retained on the model (defaults to false → no-op filter) so the
    // search pipeline stays unchanged; only the UI to mutate it is gone.

    private func chipLabel(text: String, systemImage: String, isOn: Bool) -> some View {
        HStack(spacing: DODSpacing.xxs) {
            Image(systemName: systemImage)
            Text(text).lineLimit(1)
        }
        .dodFont(DODType.caption)
        .foregroundStyle(isOn ? DODColor.cream : DODColor.label)
        .padding(.horizontal, DODSpacing.sm)
        .padding(.vertical, DODSpacing.xxs)
        .background(
            Capsule().fill(isOn ? DODColor.castIronBrown : DODColor.surfaceElevated)
        )
    }
}

// `FlowLayout` lives in `FlowLayout.swift` and `IdleSuggestionsView`
// lives in `IdleSuggestionsView.swift` to keep this file under
// SwiftLint's 400-line cap (the file overran on T-580 / T-590 then
// again on T-650 — the `FlowLayout` split landed in T-620 incidentally
// and the `IdleSuggestionsView` split lands in T-650 for the same
// reason). Both helpers have no logical dependency on the rest of
// `SearchView`'s source.
