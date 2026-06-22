import DODDesignSystem
import DODDomain
import DODSupport
import SwiftUI

/// Home feed screen. Pull-to-refresh + infinite scroll + offline banner +
/// first-launch-offline empty state.
///
/// Tapping a row is broadcast via `onSelect` so the app composition root
/// can navigate without this module knowing about the detail feature.
public struct FeedView: View {

    @State private var viewModel: FeedViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// System `openURL` (RootView's override). The Cooking Tools menu's "Buy
    /// BuzzyWaxx Seasoning" item hands off to the browser — buzzywaxx.com isn't a
    /// DOD recipe link, so RootView's override falls through to `.systemAction`.
    @Environment(\.openURL) private var openURL
    /// US-38 / AC-38.2 / CL-64 (T-650, 2026-05-27) — shared with `SearchView`
    /// via the same `@AppStorage` key. Default `.gallery` preserves CC-9's
    /// 2-column grid byte-for-byte for users who never tap the toggle.
    @AppStorage(RecipeListLayout.storageKey) private var layoutRaw: String =
        RecipeListLayout.gallery.rawValue
    /// DUT-183 — presents the guided "Your First Cookout" flow as a sheet.
    @State private var showingFirstCookout = false
    /// DUT-104 — presents the "I Made This" cook journal as a sheet.
    @State private var showingJournal = false
    /// DUT-190 — presents the "cook a dump cake" picker + coached flow as a sheet.
    @State private var showingDumpCakeFlow = false
    /// DUT-196 — presents the Dutch Oven Heat Coach as a sheet. Moved here from
    /// Settings ▸ Tools so all cooking-help + cast-iron-care tools live together
    /// in the Feed's "Cooking Tools" menu.
    @State private var showingHeatCoach = false
    /// DUT-183 — the "Start Here" First Cookout hero card; dismissible + persisted
    /// so a cook past their first win isn't nagged (the toolbar flame stays).
    @AppStorage("dod.firstCookoutHeroDismissed") private var firstCookoutHeroDismissed = false
    /// DUT-183 — the cook's current rung on the path (the next dish they haven't
    /// cooked yet). Defaults to rung 1; recomputed from the cook journal so the
    /// hero + flow follow the user up the ladder. nil once every rung is cooked.
    @State private var currentRung: GuidedCookout? = .firstCookout
    public let onSelect: (RecipeListItem) -> Void
    /// US-34 / AC-34.1 — long-press → "Save" context menu wiring. Optional
    /// so existing callers (tests, previews) don't need to plumb it. nil
    /// here means the context menu still appears but the Save button is a
    /// no-op; production callers (TabStack) always pass a non-nil closure
    /// that routes through `RecipeStore.toggleSaved` per CL-59.
    public let onSave: ((RecipeListItem) -> Void)?

    public init(
        viewModel: FeedViewModel,
        onSelect: @escaping (RecipeListItem) -> Void,
        onSave: ((RecipeListItem) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
        self.onSave = onSave
    }

    public var body: some View {
        ZStack(alignment: .top) {
            content
            OfflineBanner(isOffline: viewModel.isOffline)
        }
        .background(DODColor.surface)
        // T-781 / DUT-87 — no `.navigationTitle`: the "Recipes & Articles" large
        // title is rendered as scrolling content (`DODScreenHeader` in `list`)
        // so it scrolls up and away instead of the native minimize, keeping every
        // tab's header behavior consistent (and dodging the iOS 26 large-title
        // bug). The `.toolbar` buttons below stay pinned in the nav bar.
        .toolbar {
            // DUT-196 — a single "Cooking Tools" menu (`frying.pan.fill`) on the
            // TRAILING edge consolidates every cooking-help + cast-iron-care
            // entry point (Your First Cookout, Cook Journal, Heat Coach, Buy
            // BuzzyWaxx) into one spot so the Feed chrome stays clean. Replaces
            // the separate First Cookout + Journal buttons (T-823) and pulls Heat
            // Coach + Shop off the Settings page. `.topBarTrailing` is iOS-only;
            // the macOS test slice falls back to `.automatic`.
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                cookingToolsMenu
            }
            #else
            ToolbarItem(placement: .automatic) {
                cookingToolsMenu
            }
            #endif
        }
        .sheet(isPresented: $showingFirstCookout) {
            // DUT-194 — start on the "pick what to cook" chooser (rungs + dump
            // cakes), with the progress-aware rung recommended. A true beginner
            // is dropped straight into coaching (CookChooserFlow.initialSelection).
            CookChooserFlow(
                recommended: currentRung,
                onLogCook: { entry in
                    Task {
                        await viewModel.logCook(entry)
                        await refreshCurrentRung()
                    }
                }
            )
        }
        .sheet(isPresented: $showingJournal) {
            CookJournalView(load: { await viewModel.cookLogs() })
        }
        .sheet(isPresented: $showingHeatCoach) {
            NavigationStack { HeatCoachView() }
        }
        .sheet(isPresented: $showingDumpCakeFlow) {
            DumpCakeFlow(onLogCook: { entry in
                Task {
                    await viewModel.logCook(entry)
                    await refreshCurrentRung()
                }
            })
        }
        .task { await viewModel.onAppear() }
        .task { await refreshCurrentRung() }
        .refreshable { await viewModel.refresh() }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isOffline)
        .sensoryFeedback(.success, trigger: viewModel.refreshCount)
    }

    /// DUT-183 — recompute the cook's current rung from the journal so the hero
    /// card + the flow advance to the next un-cooked dish as they climb the path.
    private func refreshCurrentRung() async {
        let cooked = Set((await viewModel.cookLogs()).map(\.recipeID))
        currentRung = GuidedCookout.nextUncookedRung(cookedRecipeIDs: cooked)
    }

    /// DUT-196 (the menu) + DUT-200 / T-833 (this refinement): one
    /// `frying.pan.fill` toolbar button that gathers every cooking-help +
    /// cast-iron-care entry
    /// point in one place. The button shows a **visible "Cooking Tools" title**
    /// (an explicit icon + text `HStack` — a toolbar `Label` collapses to
    /// icon-only), and each item carries a one-line **description** of what it
    /// is + why it matters on the Dutch-oven learning journey — a second `Text`
    /// in a menu `Button`'s label renders as the item's subtitle. Each item
    /// triggers its existing sheet / browser hand-off.
    private var cookingToolsMenu: some View {
        Menu {
            Button {
                showingFirstCookout = true
            } label: {
                Text("Your First Cookout")
                Text("Your guided first win, coached start to finish.")
                Image(systemName: "flame.fill")
            }
            .accessibilityIdentifier("cooking-tools-first-cookout")
            Button {
                showingJournal = true
            } label: {
                Text("Cook Journal")
                Text("Track every cook and build your streak.")
                Image(systemName: "book.closed.fill")
            }
            .accessibilityIdentifier("cooking-tools-journal")
            Button {
                showingHeatCoach = true
            } label: {
                Text("Dutch Oven Heat Coach")
                Text("Get the coals right for any temperature.")
                Image(systemName: "thermometer.medium")
            }
            .accessibilityIdentifier("cooking-tools-heat-coach")
            Button {
                openCookingToolURL(SettingsViewModel.buyBuzzyWaxxURLString)
            } label: {
                Text("Buy BuzzyWaxx Seasoning")
                Text("Season and protect your cast iron.")
                Image(systemName: "bag.fill")
            }
            .accessibilityIdentifier("cooking-tools-buy-buzzywaxx")
        } label: {
            // Explicit HStack (not a `Label` + `.labelStyle`) so the nav bar
            // actually renders the visible "Cooking Tools" title next to the
            // pan — a toolbar `Label` collapses to icon-only.
            HStack(spacing: DODSpacing.xxs) {
                Image(systemName: "frying.pan.fill")
                Text("Cooking Tools")
                    .dodFont(DODType.body)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Cooking Tools")
        }
        .tint(DODColor.burntOrange)
        .accessibilityIdentifier("feed-toolbar-cooking-tools")
    }

    /// Hand a Cooking Tools URL (the BuzzyWaxx storefront) to the browser. Built
    /// with `if let` from the `String` constant so the repo's
    /// `force_unwrapping`-as-error lint stays clean (mirrors the old `ShopSection`).
    private func openCookingToolURL(_ string: String) {
        if let url = URL(string: string) {
            openURL(url)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loadingInitial:
            loadingSkeletons
        case .firstLaunchOffline:
            EmptyState(
                systemImage: "wifi.slash",
                title: "You need internet",
                message: "Connect to load recipes the first time.",
                action: .init(title: "Retry") {
                    Task { await viewModel.refresh() }
                }
            )
        case .empty:
            EmptyState(
                systemImage: "tray",
                title: "No recipes",
                message: "Check back soon."
            )
        case .idle, .loaded, .loadingMore:
            list
        }
    }

    private var list: some View {
        // US-38 / AC-38.3 / AC-38.4 (T-650): branch on the persisted
        // layout. `.gallery` keeps the existing 2-col `LazyVGrid` body
        // byte-identical (CC-9 contract preserved); `.list` renders a
        // `LazyVStack` of `RecipeCard.ListRow` rows for denser scanning.
        let layout = RecipeListLayout(rawValue: layoutRaw) ?? .gallery
        return ScrollView {
            // T-781 / DUT-87 — the title scrolls with the content (no native
            // minimize); offline shifts it below the OfflineBanner overlay.
            DODScreenHeader("Recipes & Articles")
                .padding(.top, viewModel.isOffline ? DODSpacing.xl : 0)
            // DUT-183 — the keystone "Your First Cookout" entry, surfaced as a
            // prominent hero so beginners actually find the coached path.
            if let currentRung, !firstCookoutHeroDismissed {
                FirstCookoutHeroCard(
                    cookout: currentRung,
                    onStart: { showingFirstCookout = true },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            firstCookoutHeroDismissed = true
                        }
                    },
                    // DUT-194 — the dump-cake shortcut now lands in the unified
                    // chooser (dump cakes are a section there).
                    onCookDumpCake: { showingFirstCookout = true }
                )
                .padding(.horizontal, DODSpacing.md)
                .padding(.top, DODSpacing.sm)
            }
            Group {
                switch layout {
                case .gallery:
                    galleryContent
                case .list:
                    listContent
                }
            }
            .padding(.horizontal, DODSpacing.md)
            .padding(.top, DODSpacing.md)

            if viewModel.loadState == .loadingMore {
                ProgressView()
                    .padding(.vertical, DODSpacing.lg)
            }
        }
    }

    /// US-38 / AC-38.3 — the existing 2-col `LazyVGrid` rendering. Body
    /// byte-identical to the pre-T-650 `list` implementation; CC-9's grid
    /// contract is preserved unchanged.
    private var galleryContent: some View {
        LazyVGrid(columns: recipeGridColumns(horizontalSizeClass: horizontalSizeClass), spacing: DODSpacing.md) {
            ForEach(viewModel.items) { item in
                FeedRow(item: item)
                    .recipeCardTap { onSelect(item) }
                    // T-765 / CL-162 (DUT-71) — state-aware Save/Unsave from the
                    // viewmodel-owned saved-id set; optimistic flip on toggle.
                    .recipeCardContextMenu(isSaved: viewModel.savedRecipeIDs.contains(item.id)) {
                        viewModel.applyOptimisticSaveToggle(id: item.id)
                        onSave?(item)
                    }
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
    private var listContent: some View {
        // T-782 / DUT-88 — iPad tiles the dense rows into a multi-column grid;
        // iPhone (compact) keeps the exact single-column LazyVStack.
        adaptiveListRows(horizontalSizeClass: horizontalSizeClass) {
            ForEach(viewModel.items) { item in
                RecipeCard.ListRow(
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage,
                    totalTimeDisplay: item.totalTimeDisplay
                )
                .recipeCardTap { onSelect(item) }
                .recipeCardContextMenu(isSaved: viewModel.savedRecipeIDs.contains(item.id)) {
                    viewModel.applyOptimisticSaveToggle(id: item.id)
                    onSave?(item)
                }
                .accessibilityIdentifier("dod.feed.card")
                .task {
                    await viewModel.loadMoreIfNeeded(currentItem: item)
                }
            }
        }
    }

    private var loadingSkeletons: some View {
        ScrollView {
            VStack(spacing: DODSpacing.md) {
                ForEach(0..<6, id: \.self) { _ in
                    LoadingSkeleton(cornerRadius: DODSpacing.sm)
                        .frame(height: 280)
                }
            }
            .padding(DODSpacing.md)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading recipes")
        }
    }
}
