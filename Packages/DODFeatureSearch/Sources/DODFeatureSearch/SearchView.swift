import DODDesignSystem
import DODDomain
import SwiftUI

public struct SearchView: View {

    // DUT-11: `internal` (no modifier) rather than `private` so the
    // `SearchView+IngredientSection.swift` extension — split out for the
    // 400-line `file_length` cap — can read the view model and size class
    // when rendering the ingredient tier. Same cross-file-extension reason
    // the `SearchViewModel` storage was promoted from `private` (CL-106).
    @State var viewModel: SearchViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    /// US-38 / AC-38.2 / CL-64 (T-650, 2026-05-27) — shared with `FeedView`
    /// via the same `@AppStorage` key. Default `.gallery` preserves the
    /// existing search-results 2-column grid byte-for-byte.
    @AppStorage(RecipeListLayout.storageKey) var layoutRaw: String =
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
            // US-3 / AC-3.5 amendment / CL-126 / REG-32 (T-648, 2026-05-30):
            // the inline `searchField` `HStack`-with-`RoundedRectangle` is
            // replaced by the shared `DODSearchField` so this bar and the
            // Categories-tab bar both render `DODColor.surfaceElevated`
            // brand brown inside a `Capsule(style: .continuous)` shape.
            // The `onClear` closure routes to `viewModel.clear()` so the
            // clear button preserves the full VM-side state/items/lastQuery/
            // debounce-cancel cleanup, not just the query-string clear.
            DODSearchField(
                text: $viewModel.query,
                placeholder: "Search recipes",
                onClear: { viewModel.clear() },
                // T-779 / DUT-85: record a Recent on keyboard dismissal (focus
                // loss), not on every live debounced search.
                onFocusChange: { focused in
                    if !focused { viewModel.commitRecentSearch() }
                }
            )
            // T-779 / DUT-85: ...and on Return.
            .onSubmit { viewModel.commitRecentSearch() }
            .padding(DODSpacing.md)
            .accessibilityIdentifier("dod.search.field.search")
            // US-12 / AC-12.2 amendment / CL-106 (T-637): hide the filter
            // chip row while idle — the `IdleSuggestionsView` "Try" /
            // "Recent" layout below already serves as the discovery
            // surface, and an above-it chip row crowded the layout. The
            // row renders the moment a search transitions to .searching
            // / .results / .noResults / .offline so the user can refine
            // narrowing while results are coming back.
            if viewModel.state != .idle {
                FilterChipRow(filters: $viewModel.filters)
            }
            // US-12 amendment / US-29 amendment / CL-127 (T-649): the
            // "did you mean?" rescue banner. Renders above the result
            // list (or the no-results empty state) whenever the
            // viewmodel computed a non-nil suggestion AND the result
            // set has settled — gated on `state == .results || state ==
            // .noResults` so the banner never flashes during the
            // `.searching` transition. Tap re-runs the search with the
            // suggested term via `viewModel.applyDidYouMean()`.
            if let suggestion = viewModel.didYouMean, shouldShowDidYouMeanBanner {
                didYouMeanBanner(suggestion: suggestion)
            }
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
        .task {
            await viewModel.loadCategoriesIfNeeded()
            await viewModel.refreshSavedRecipeIDs()  // T-765: state-aware menu on appear
        }
    }

    /// CL-127 (T-649): gate the banner on a settled state so it never
    /// flashes during `.searching`. Computed property keeps the
    /// `if let ..., shouldShow` call site under SwiftLint's
    /// brace-spacing rule.
    private var shouldShowDidYouMeanBanner: Bool {
        viewModel.state == .results || viewModel.state == .noResults
    }

    /// US-12 amendment / US-29 amendment / CL-127 (T-649): the
    /// "did you mean?" tappable banner. Brand accent + underline so
    /// it reads as a one-tap rescue affordance over the sparse result
    /// list. Combined accessibility element so VoiceOver announces
    /// the full intent in one swipe.
    private func didYouMeanBanner(suggestion: String) -> some View {
        HStack(spacing: DODSpacing.xs) {
            Text("Did you mean:")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            Text(suggestion)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.accent)
                .underline()
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.applyDidYouMean() }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Did you mean \(suggestion)? Tap to search.")
        .accessibilityIdentifier("dod.search.didYouMean")
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            IdleSuggestionsView(
                recents: viewModel.recentSearches,
                // T-639 / CL-117: source the Try pills from the rotating
                // `displayedTrySlate` (per-cold-launch shuffle, stable
                // within session, Latest Recipes pinned first) instead
                // of the pre-rotation `topCategorySuggestions` top-5.
                topCategories: viewModel.displayedTrySlate,
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
                    // US-29 / AC-29.1 amendment / CL-106 (T-637): the
                    // "Latest Recipes" category (id 1590, slug
                    // `latest-recipes` — confirmed by SubTypeTests.swift)
                    // is special-cased. Running `selectCuratedSuggestion`
                    // with the literal name would fire a fulltext REST
                    // search for "Latest Recipes" which returns garbage
                    // (the phrase appears in many unrelated articles'
                    // boilerplate). Case-insensitive name match is the
                    // canonical check (robust against future renames);
                    // the id check is a belt-and-suspenders fallback in
                    // case the name drifts. Every other category falls
                    // through to the normal curated-tap path (CL-49).
                    let isLatestRecipes =
                        category.id == 1590
                        || category.name.localizedCaseInsensitiveCompare("Latest Recipes")
                            == .orderedSame
                    if isLatestRecipes {
                        Task { await viewModel.surfaceLatestRecipes() }
                    } else {
                        viewModel.selectCuratedSuggestion(category.name)
                    }
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
            // US-38 / AC-38.3 / AC-38.4 (T-650) + DUT-11: the scrolling
            // results body (title tier + the labeled "Recipes using <term>"
            // ingredient tier) lives in `SearchView+IngredientSection.swift`
            // so this file stays under SwiftLint's 400-line `file_length` cap.
            resultsScroll(layout: RecipeListLayout(rawValue: layoutRaw) ?? .gallery)
        }
    }

    /// US-38 / AC-38.3 — existing 2-col grid. Body byte-identical to the
    /// pre-T-650 `.results` rendering. DUT-11: `internal` so the
    /// `+IngredientSection` extension's `resultsScroll` can compose it.
    var galleryResults: some View {
        LazyVGrid(
            columns: recipeGridColumns(horizontalSizeClass: horizontalSizeClass),
            spacing: DODSpacing.md
        ) {
            ForEach(viewModel.items) { item in
                RecipeCard(
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage,
                    totalTimeDisplay: item.totalTimeDisplay,
                    highlightQuery: viewModel.query
                )
                .recipeCardTap { onSelect(item) }
                .recipeCardContextMenu(isSaved: viewModel.savedRecipeIDs.contains(item.id)) {
                    viewModel.applyOptimisticSaveToggle(id: item.id)
                    onSave?(item)
                }
                // T-737 / L5: stable handle mirroring `dod.feed.card`.
                .accessibilityIdentifier("dod.search.card")
            }
        }
    }

    /// US-38 / AC-38.4 — dense single-column variant. Composes the same
    /// tap + context-menu modifiers as the gallery so US-34 / AC-34.1
    /// / AC-34.6 long-press-Save/Unsave works identically. DUT-11:
    /// `internal` so the `+IngredientSection` extension can compose it.
    var listResults: some View {
        LazyVStack(spacing: DODSpacing.xs) {
            ForEach(viewModel.items) { item in
                RecipeCard.ListRow(
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage,
                    totalTimeDisplay: item.totalTimeDisplay,
                    highlightQuery: viewModel.query
                )
                .recipeCardTap { onSelect(item) }
                .recipeCardContextMenu(isSaved: viewModel.savedRecipeIDs.contains(item.id)) {
                    viewModel.applyOptimisticSaveToggle(id: item.id)
                    onSave?(item)
                }
                .accessibilityIdentifier("dod.search.card")
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
    /// CL-122 (T-644): the chip is a `Button` that opens the wheel-picker
    /// half-sheet instead of the pre-T-644 inline `Menu`. The sheet is
    /// presented from the row so the chip itself stays a one-liner.
    @State private var cookTimeSheetPresented: Bool = false

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
        // CL-122 (T-644): half-sheet hosting the two-wheel min/max picker.
        // Drag-down dismisses without applying (no auto-commit on
        // selection change — Apple-Timer pattern). The sheet's "Apply"
        // button writes the committed selection back into `$filters`.
        .sheet(isPresented: $cookTimeSheetPresented) {
            CookTimeRangeSheet(
                initialMinSeconds: filters.cookTimeMinSeconds,
                initialMaxSeconds: filters.cookTimeMaxSeconds,
                onApply: { newMin, newMax in
                    filters.cookTimeMinSeconds = newMin
                    filters.cookTimeMaxSeconds = newMax
                    cookTimeSheetPresented = false
                },
                onCancel: { cookTimeSheetPresented = false }
            )
            // T-646 / CL-124 — content-fitted custom detent (was `.medium`
            // which left a tall dead-space tail above the home indicator).
            // 340pt comfortably hosts header + wheels (160) + Apply + Reset
            // + reduced bottom padding + the home-indicator safe area.
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
            // T-645 / CL-123 — fill the system sheet chrome with the
            // brand surface color so the brown (dark) / white (light)
            // panel reaches the bottom of the screen instead of letting
            // the default chrome blur show through the safe-area gap.
            .presentationBackground(DODColor.surface)
        }
    }

    // US-29 / AC-29.4 / CL-49.4 + CL-105 (T-636): the "All categories"
    // filter chip was removed because the Categories tab (bottom nav)
    // already serves as the canonical "browse all categories" surface,
    // making the chip duplicative. `filters.categoryID` is retained on
    // the model (always nil here → "all categories" pipeline path) so
    // the search merge logic remains untouched; only the UI affordance
    // to mutate it is gone.

    private var cookTimeChip: some View {
        let label = cookTimeChipLabel(
            min: filters.cookTimeMinSeconds,
            max: filters.cookTimeMaxSeconds
        )
        return Button {
            cookTimeSheetPresented = true
        } label: {
            chipLabel(
                text: label,
                systemImage: "clock",
                isOn: filters.hasCookTimeRange
            )
        }
        .accessibilityLabel("Cook time filter, \(label)")
        // T-638 / CL-107 — stable test handle for the L5 E2E
        // `test_search_chip_row_hidden_on_idle` (negative-asserts the chip is
        // not queryable on the idle Search tab — pins CL-106 part 1's
        // `viewModel.state != .idle` gate) and `test_search_cook_time_filter_narrows_results`
        // (taps the chip → opens the wheel sheet → picks max → asserts the
        // filtered result count narrows via the hydration path — pins
        // CL-106 part 2 + REG-21 + REG-31).
        .accessibilityIdentifier("dod.search.cookTimeChip")
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

// `FlowLayout` (FlowLayout.swift), `IdleSuggestionsView`
// (IdleSuggestionsView.swift), and the DUT-25 search-field affordance
// (SearchFieldAffordance.swift) live in their own files to keep this one
// under SwiftLint's 400-line cap. None depend on `SearchView`'s source.
