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
    // DUT-700 PR-A — Reduce-Motion gate for the shopping-list snackbar ease.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// US-38 / AC-38.2 / CL-64 (T-650, 2026-05-27) — shared with `FeedView`
    /// via the same `@AppStorage` key. Default `.gallery` preserves the
    /// existing search-results 2-column grid byte-for-byte.
    @AppStorage(RecipeListLayout.storageKey) var layoutRaw: String =
        RecipeListLayout.gallery.rawValue
    public let onSelect: (RecipeListItem) -> Void
    /// US-34 / AC-34.1 — long-press → "Save" context menu wiring. See
    /// `FeedView.onSave` for the contract (DUT-629 success completion incl.).
    public let onSave: ((RecipeListItem, @escaping @MainActor (Bool) -> Void) -> Void)?
    /// T-799 / CL-193 — browse-category tap → host pushes the category's
    /// recipes. Defaulted no-op; `TabStack` wires `path.append(.category)`.
    public let onSelectCategory: (DODDomain.Category) -> Void
    /// DUT-534 Part 2 — the Shopping List snackbar's "View" action opens the
    /// Shopping List (`dod://shopping-list`). Optional so existing callers
    /// (tests / previews) can omit it; when nil the append still works but the
    /// success snackbar shows no "View" button (mirrors Recipe Detail's Part 1
    /// `openShoppingList` seam threaded through `TabStack`).
    public let openShoppingList: (() -> Void)?
    /// DUT-551 (CL-306) — opens the Settings sheet from the header's trailing
    /// gear (Settings left the tab bar; the gear now lives on every main tab).
    /// Optional + default nil so existing callers / previews / snapshots show no
    /// gear and stay unaffected. Production wires it through `TabStack`.
    public let onOpenSettings: (() -> Void)?

    public init(
        viewModel: SearchViewModel,
        onSelect: @escaping (RecipeListItem) -> Void,
        onSave: ((RecipeListItem, @escaping @MainActor (Bool) -> Void) -> Void)? = nil,
        onSelectCategory: @escaping (DODDomain.Category) -> Void = { _ in },
        openShoppingList: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
        self.onSave = onSave
        self.onSelectCategory = onSelectCategory
        self.openShoppingList = openShoppingList
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        VStack(spacing: 0) {
            // T-843 / DUT-261 — shared `DODScreenHeader` (large, left-aligned,
            // `DODColor.label`), pinned above the search field, so Search matches
            // Recipes / Saved / Settings instead of a native white nav title.
            // DUT-551 (CL-306) — Settings gear in the trailing slot when wired.
            DODScreenHeader("Search") {
                // DUT-572 — gear only in compact width (iPhone); iPad's sidebar
                // already has a Settings row, so it's redundant in regular width.
                if let onOpenSettings, horizontalSizeClass == .compact {
                    DODHeaderGearButton { onOpenSettings() }
                }
            }
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
                placeholder: "Search Recipes",
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
        // DUT-527 — announce the result count once the search settles, so a
        // VoiceOver user hears how many recipes came back (or that none did)
        // instead of silently landing in the results list. Gated on the two
        // terminal states so the transient `.searching` flip never speaks.
        .onChange(of: viewModel.state) { _, newState in
            announceSearchState(newState)
        }
        // DUT-534 Part 2 — bottom "Add to Shopping List" snackbar host (mirrors
        // Recipe Detail Part 1). DUT-700 PR-A drives its transition, RM-gated.
        .overlay(alignment: .bottom) { shoppingListSnackbar }
        .animation(reduceMotion ? nil : .default, value: viewModel.shoppingListSnackbarMessage)
        .background(DODColor.surface)
        // DUT-275 — nav bar hidden so the title pins at the very top, at the same
        // Y as every other tab (the title is the `DODScreenHeader` above).
        .dodHidesNavBar()
        .task {
            await viewModel.loadCategoriesIfNeeded()
            await viewModel.refreshSavedRecipeIDs()  // T-765: state-aware menu on appear
        }
    }

    /// DUT-527 — announce the result count once the search settles, so a
    /// VoiceOver user hears how many recipes came back (or that none did).
    private func announceSearchState(_ state: SearchViewModel.State) {
        let message: String
        switch state {
        case .results:
            // DUT-693 — `.results` covers title- OR ingredient-tier hits; count both.
            let count = viewModel.items.count + viewModel.ingredientItems.count
            message = "\(count) \(count == 1 ? "recipe" : "recipes") found."
        case .noResults:
            message = "No recipes found."
        case .error:
            // DUT-622: announce the failure so a VoiceOver user isn't left in silence.
            message = "Search couldn't load. Try again."
        case .offline:
            // DUT-729: terminal user-facing offline state — announce like `.error`.
            message = "Search needs internet. Reconnect to try again."
        case .idle, .searching:
            return
        }
        AccessibilityNotification.Announcement(message).post()
    }

    /// CL-127 (T-649): gate the banner on a settled state so it never
    /// flashes during `.searching`. Computed property keeps the
    /// `if let ..., shouldShow` call site under SwiftLint's
    /// brace-spacing rule.
    private var shouldShowDidYouMeanBanner: Bool {
        viewModel.state == .results || viewModel.state == .noResults
    }

    /// DUT-534 Part 2 — the bottom "Add to Shopping List" confirmation snackbar.
    /// Present only while the view model set a message; a `.task` auto-dismisses
    /// it after a few seconds (mirrors Recipe Detail's Part 1 snackbar, DUT-419).
    /// `internal` so the `+IngredientSection` extension can host it too — but the
    /// overlay is attached once on the shared `body`, so this is read here only.
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

    /// US-12 amendment / US-29 amendment / CL-127 (T-649): the "did you mean?"
    /// tappable banner. Brand accent + underline so it reads as a one-tap rescue
    /// affordance over the sparse result list. Combined accessibility element +
    /// `.isButton` trait so VoiceOver announces the full intent as a button.
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
        // DUT-527 — guarantee a 44pt tap target for the tappable rescue banner.
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.applyDidYouMean() }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
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
                    // US-29 / AC-29.1 amendment / CL-106 (T-637): "Latest
                    // Recipes" is special-cased — a literal `selectCuratedSuggestion`
                    // fulltext search for the phrase returns garbage; every other
                    // category falls through to the curated-tap path.
                    // DUT-693 — the id-1590 / name-match test is now the canonical
                    // `nonisolated static` predicate on the view model
                    // (`SearchViewModel+T639.swift`); this call site and
                    // `IdleSuggestionsView` both delegate to it.
                    if SearchViewModel.isLatestRecipesCategory(category) {
                        Task { await viewModel.surfaceLatestRecipes() }
                    } else {
                        viewModel.selectCuratedSuggestion(category.name)
                    }
                },
                onClearRecents: { viewModel.clearRecentSearches() },
                // US-33 / AC-33.3 / CL-57: per-term context-menu Clear.
                onRemoveRecent: { viewModel.removeRecentSearch($0) },
                // T-799 / CL-193: browse-categories list + tap handler.
                categories: viewModel.browseCategories,
                onCategorySelect: onSelectCategory
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
            // DUT-693 — offline only re-fired on a query TEXT change, so an
            // unchanged query dead-ended; "Try Again" re-runs via `retrySearch()`.
            EmptyState(
                systemImage: "wifi.slash",
                title: "Search needs internet",
                message: "Reconnect to search dutchovendaddy.com.",
                action: .init(title: "Try Again") {
                    Task { await viewModel.retrySearch() }
                }
            )
            .accessibilityIdentifier("dod.search.offlineState")
        case .error:
            // DUT-622: the online request FAILED (vs genuinely finding nothing),
            // so offer a Retry rather than the dead-end "No recipes match"
            // screen. Tapping Retry re-runs the same query.
            EmptyState(
                systemImage: "exclamationmark.arrow.circlepath",
                title: "Search Couldn't Load",
                message: "Something went wrong reaching dutchovendaddy.com. Try again.",
                action: .init(title: "Retry") {
                    Task { await viewModel.retrySearch() }
                }
            )
            .accessibilityIdentifier("dod.search.errorState")
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
                // CL-255 — cook-time chip omitted (browse declutter); Search's
                // time filter covers cook time for those who want it.
                RecipeCard(
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage,
                    highlightQuery: viewModel.query
                )
                .recipeCardTap { onSelect(item) }
                .recipeCardContextMenu(
                    isSaved: viewModel.savedRecipeIDs.contains(item.id),
                    onToggle: {
                        // DUT-629 — optimistic flip, re-inverted on write failure.
                        viewModel.applyOptimisticSaveToggle(id: item.id)
                        onSave?(item) { didSave in
                            if !didSave { viewModel.applyOptimisticSaveToggle(id: item.id) }
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

    /// US-38 / AC-38.4 — dense single-column variant. Composes the same
    /// tap + context-menu modifiers as the gallery so US-34 / AC-34.1
    /// / AC-34.6 long-press-Save/Unsave works identically. DUT-11:
    /// `internal` so the `+IngredientSection` extension can compose it.
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
                    highlightQuery: viewModel.query
                )
                .recipeCardTap { onSelect(item) }
                .recipeCardContextMenu(
                    isSaved: viewModel.savedRecipeIDs.contains(item.id),
                    onToggle: {
                        // DUT-629 — optimistic flip, re-inverted on write failure.
                        viewModel.applyOptimisticSaveToggle(id: item.id)
                        onSave?(item) { didSave in
                            if !didSave { viewModel.applyOptimisticSaveToggle(id: item.id) }
                        }
                    },
                    onAddToShoppingList: { Task { await viewModel.addToShoppingList(item) } }
                )
                .accessibilityIdentifier("dod.search.card")
            }
        }
    }
}

// `FlowLayout`, `FilterChipRow`, `IdleSuggestionsView`, and the DUT-25
// search-field affordance each live in their own file to keep this one under
// SwiftLint's 400-line cap. None depend on `SearchView`'s source.
