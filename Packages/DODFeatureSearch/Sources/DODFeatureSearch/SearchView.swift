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
    /// v2 Search overhaul (2/3) — tracks search-field keyboard focus so the
    /// type-ahead suggestions only show WHILE the user is actively typing (they
    /// hide once the keyboard dismisses / a card is tapped). Fed by
    /// `DODSearchField`'s `onFocusChange`. `internal` so the
    /// `SearchView+Suggestions.swift` extension can gate the list on it.
    @State var isFieldFocused = false
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
    /// v2 Search overhaul (2/3) — Search is now presented as a bottom-up modal
    /// (`.sheet`) from the Feed header's magnifying glass, not a pushed screen.
    /// A sheet dismisses via a top-right "Done" (the repo nav convention —
    /// system chevron for pushes, Done for sheets). When wired, the header's
    /// trailing slot shows this Done button instead of the Settings gear (the
    /// modal is a focused search context; Settings stays on the Feed root).
    /// Optional + default nil so existing callers / previews / snapshots are
    /// unaffected. Production wires it through `TabStack`.
    public let onDone: (() -> Void)?

    public init(
        viewModel: SearchViewModel,
        onSelect: @escaping (RecipeListItem) -> Void,
        onSave: ((RecipeListItem, @escaping @MainActor (Bool) -> Void) -> Void)? = nil,
        onSelectCategory: @escaping (DODDomain.Category) -> Void = { _ in },
        openShoppingList: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        onDone: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
        self.onSave = onSave
        self.onSelectCategory = onSelectCategory
        self.openShoppingList = openShoppingList
        self.onOpenSettings = onOpenSettings
        self.onDone = onDone
    }

    public var body: some View {
        VStack(spacing: 0) {
            // T-843 / DUT-261 — shared `DODScreenHeader` (large, left-aligned,
            // `DODColor.label`), pinned above the search field, so Search matches
            // Recipes / Saved / Settings instead of a native white nav title.
            // DUT-551 (CL-306) — Settings gear in the trailing slot when wired.
            DODScreenHeader("Search") {
                // v2 Search overhaul (2/3) — presented as a bottom-up `.sheet`,
                // so the trailing slot hosts a "Done" dismissal (the repo
                // sheet convention). It takes precedence over the Settings gear:
                // the modal is a focused search context and the Feed root
                // already owns the Settings gear.
                if let onDone {
                    Button("Done") { onDone() }
                        .dodFont(DODType.bodyEmphasized)
                        .tint(DODColor.burntOrange)
                        // 44pt HIG tap target (matches DODHeaderGearButton).
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("search-done")
                } else if let onOpenSettings, horizontalSizeClass == .compact {
                    // DUT-572 — gear only in compact width (iPhone); iPad's
                    // sidebar already has a Settings row, redundant in regular.
                    DODHeaderGearButton { onOpenSettings() }
                }
            }
            // US-3 / AC-3.5 / CL-126 / REG-32 (T-648): the shared `DODSearchField`
            // (brand-brown `Capsule`, matching the Categories bar) replaces the inline
            // field; `onClear` routes to `viewModel.clear()` for full VM-side cleanup.
            DODSearchField(
                text: $viewModel.query,
                placeholder: "Search Recipes",
                onClear: { viewModel.clear() },
                // T-779 / DUT-85: record a Recent on keyboard dismissal (focus
                // loss), not on every live debounced search.
                onFocusChange: { focused in
                    // v2 Search overhaul (2/3): drive the type-ahead visibility.
                    isFieldFocused = focused
                    if !focused { viewModel.commitRecentSearch() }
                }
            )
            // T-779 / DUT-85: ...and on Return.
            .onSubmit { viewModel.commitRecentSearch() }
            .padding(DODSpacing.md)
            .accessibilityIdentifier("dod.search.field.search")
            // v2 Search overhaul (2/3) — type-ahead suggestions, shown directly
            // under the field WHILE it's focused and the local title pool
            // yielded matches. Lives in `SearchView+Suggestions.swift`.
            if isFieldFocused, !viewModel.suggestions.isEmpty {
                suggestionsList
            }
            // US-12 / AC-12.2 amendment / CL-106 (T-637): hide the filter
            // chip row while idle — the `IdleSuggestionsView` "Try" /
            // "Recent" layout below already serves as the discovery
            // surface, and an above-it chip row crowded the layout. The row
            // renders the moment a search leaves idle so the user can refine.
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
        // US-34 / AC-34.6 — `.selection` tap on a genuine card Save/Unsave, keyed
        // to `saveToggleCount` so appear/refresh recon never buzzes (cf. Categories).
        .sensoryFeedback(.selection, trigger: viewModel.saveToggleCount)
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
                // v2 Search overhaul (3/3): source the Try chips from
                // `displayedTrySlate` — a per-cold-launch shuffle over the
                // curated 100-term `SearchTryChips.pool` (stable within
                // session, Latest Recipes pinned first).
                tryChips: viewModel.displayedTrySlate,
                onRecentTap: { viewModel.selectRecent($0) },
                // v2 Search overhaul (3/3): tapping a "Try" chip runs a normal
                // TEXT search for its RAW `query` (the Title-Cased label is
                // display-only), through the same debounce path as typing.
                //
                // REG-19 / CL-66 / T-670: route through
                // `selectCuratedSuggestion(_:)` (not raw `query = ...`) so the
                // resulting REST search does NOT persist the tapped term into
                // the recent-searches store. The user tapped a curated chip;
                // they did not type the term. Persisting it makes Clear All
                // look broken because the same curated terms reappear under
                // Recent.
                onTryChipTap: { chip in
                    // CL-106 (T-637): "Latest Recipes" stays special — a
                    // literal fulltext search for the phrase returns garbage,
                    // so the pinned chip runs the recent-posts fetch instead.
                    if chip.isLatestRecipes {
                        Task { await viewModel.surfaceLatestRecipes() }
                    } else {
                        viewModel.selectCuratedSuggestion(chip.query)
                    }
                },
                onClearRecents: { viewModel.clearRecentSearches() },
                // US-33 / AC-33.3 / CL-57: per-term context-menu Clear.
                onRemoveRecent: { viewModel.removeRecentSearch($0) },
                // T-799 / CL-193: browse-categories list + tap handler.
                categories: viewModel.browseCategories,
                onCategorySelect: onSelectCategory,
                // v2 Search overhaul (1/3) — Surprise Me lives on the idle page now
                // (moved off the Feed header); it opens a random recipe via `onSelect`.
                isSurpriseMeLoading: viewModel.isSurpriseMeLoading,
                onSurpriseMe: { Task { await viewModel.surpriseMe(onSelect: onSelect) } }
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
}

// `FlowLayout`, `FilterChipRow`, `IdleSuggestionsView` (which hosts the v2
// Surprise Me affordance), and the DUT-25 search-field affordance each live in
// their own file (400-line cap).
