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
    /// DUT-236 — tapping the Cooking Tools callout presents the same tools as the
    /// menu button (a SwiftUI `Menu` can't be opened programmatically).
    @State private var showingCookingToolsDialog = false
    /// DUT-200 — the Cooking Tools onboarding callout (the speech bubble under
    /// the menu button); dismissible + persisted so it nudges once. Replaced the
    /// First Cookout hero card (DUT-183) as the Feed's single onboarding nudge.
    @AppStorage("dod.cookingToolsCalloutDismissed") private var cookingToolsCalloutDismissed = false
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
            VStack(spacing: 0) {
                // DUT-275 — the "Recipes & Articles" title + the Cooking Tools
                // button share one header row at the very top (the nav bar is
                // hidden). With the button in the content row instead of the nav
                // bar, NO nav-bar height is reserved, so this title sits at the
                // exact same Y as every other tab's title (Search/Settings/Saved).
                DODScreenHeader("Recipes & Articles") { cookingToolsMenu }
                // DUT-275 — the onboarding callout floats ON TOP of the content
                // (below the header row) as a dismissible popup, so it never
                // pushes the pinned title/content down; its tail points up at the
                // Cooking Tools button in the header row.
                content
                    .overlay(alignment: .top) { cookingToolsCalloutOverlay }
            }
            // Offline shifts the whole stack below the OfflineBanner overlay.
            .padding(.top, viewModel.isOffline ? DODSpacing.xl : 0)
            OfflineBanner(isOffline: viewModel.isOffline)
        }
        .background(DODColor.surface)
        // DUT-275 — nav bar hidden: the "Cooking Tools" menu (DUT-196) now lives
        // in the pinned header row above (next to the title) instead of the nav
        // bar, so no nav-bar height is reserved and the title sits at the same top
        // Y as every other tab. Pushed detail screens keep their own nav bar.
        .dodHidesNavBar()
        .sheet(
            isPresented: $showingFirstCookout,
            onDismiss: { viewModel.cookoutFlowDidDismiss() },
            content: {
                // DUT-194 — start on the "pick what to cook" chooser (rungs + dump
                // cakes), with the progress-aware rung recommended. A true beginner
                // is dropped straight into coaching (CookChooserFlow.initialSelection).
                CookChooserFlow(
                    recommended: currentRung,
                    onLogCook: { logCookAndRefresh($0) }
                )
                // DUT-339 — defer any earned celebration until this sheet dismisses.
                .onAppear { viewModel.cookoutFlowWillPresent() }
            }
        )
        .sheet(isPresented: $showingJournal) { cookJournalSheet }
        // DUT-323 — celebration: a logged cook that graduates the First Cookout
        // path or bumps a rank fires the moment, once the cookout sheet closes.
        .sheet(
            item: Binding(
                get: { viewModel.celebration },
                set: { if $0 == nil { viewModel.dismissCelebration() } }
            )
        ) { celebration in
            CookCelebrationView(celebration: celebration) { viewModel.dismissCelebration() }
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingHeatCoach) {
            NavigationStack { HeatCoachView() }
        }
        // DUT-236 — the Cooking Tools callout's tap target: the same tools the
        // menu button lists, presented as a dialog (a `Menu` can't be opened
        // programmatically).
        .confirmationDialog(
            "Cooking Tools",
            isPresented: $showingCookingToolsDialog,
            titleVisibility: .visible
        ) {
            Button("Your First Cookout") { showingFirstCookout = true }
            Button("Cooking Journal") { showingJournal = true }
            Button("Dutch Oven Heat Coach") { showingHeatCoach = true }
            Button("Buy BuzzyWaxx Seasoning") {
                openCookingToolURL(SettingsViewModel.buyBuzzyWaxxURLString)
            }
        }
        .sheet(
            isPresented: $showingDumpCakeFlow,
            onDismiss: { viewModel.cookoutFlowDidDismiss() },
            content: {
                DumpCakeFlow(onLogCook: { logCookAndRefresh($0) })
                    // DUT-339 — defer any earned celebration until this sheet dismisses.
                    .onAppear { viewModel.cookoutFlowWillPresent() }
            }
        )
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

    /// DUT-196 (the menu) + DUT-200 / T-834 (this refinement): one icon-only
    /// `frying.pan.fill` toolbar button that gathers every cooking-help +
    /// cast-iron-care entry point in one place. Each item carries a one-line
    /// **description** of what it is + why it matters on the Dutch-oven learning
    /// journey (a second `Text` in a menu `Button`'s label renders as the item's
    /// subtitle). What the button *is* gets introduced by the dismissible
    /// `CookingToolsCallout` speech bubble below it (which replaced the First
    /// Cookout hero card). Each item triggers its existing sheet / browser
    /// hand-off.
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
                Text("Cooking Journal")
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
            // Icon-only (`frying.pan.fill`); the "Cooking Tools" wording lives in
            // the onboarding `CookingToolsCallout` speech bubble below the button
            // instead of a nav-bar label, keeping the chrome to one clean button.
            Image(systemName: "frying.pan.fill")
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
        // DUT-275 — the title is now pinned above `content` in `body`, and the
        // Cooking Tools callout floats as an overlay; `list` is just the grid.
        let layout = RecipeListLayout(rawValue: layoutRaw) ?? .gallery
        return ScrollView {
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

    /// DUT-275 — the onboarding "Cooking Tools" speech bubble, rendered as a
    /// floating overlay (a dismissible popup ON TOP of the content) so it never
    /// shifts the pinned title or the grid down. Its upward trailing tail points
    /// at the Cooking Tools button in the nav bar (DUT-200). Dismissible +
    /// persisted; once dismissed the Feed is the clean pinned title + grid.
    @ViewBuilder
    private var cookingToolsCalloutOverlay: some View {
        if !cookingToolsCalloutDismissed {
            CookingToolsCallout(
                onDismiss: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        cookingToolsCalloutDismissed = true
                    }
                },
                // DUT-236 — "Tap here" now opens the Cooking Tools (presented as a
                // dialog, since a Menu can't be opened programmatically) and
                // dismisses the nudge, since the user engaged with it.
                onActivate: {
                    showingCookingToolsDialog = true
                    withAnimation(.easeInOut(duration: 0.25)) {
                        cookingToolsCalloutDismissed = true
                    }
                }
            )
            .padding(.horizontal, DODSpacing.md)
            .padding(.top, DODSpacing.sm)
            .transition(.opacity.combined(with: .move(edge: .top)))
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
                // CL-254 (feed declutter) — no cook-time chip on the Recipes
                // feed (noise); `totalTimeDisplay` omitted (defaults to nil).
                // Time still shows on Search + the recipe detail page.
                RecipeCard.ListRow(
                    title: item.title,
                    excerpt: item.excerpt,
                    heroImageURL: item.heroImage
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
                    LoadingSkeleton(cornerRadius: DODRadius.standard)
                        .frame(height: 280)
                }
            }
            .padding(DODSpacing.md)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading recipes")
        }
    }
}

extension FeedView {
    /// CL-273 — the Cooking Journal sheet: loads the logged cooks and wires the
    /// per-entry reflection/photo save (`updateCook`, which never changes the
    /// cook count, so it can't affect rank). Extracted here so `FeedView`'s
    /// struct body stays under SwiftLint's `type_body_length` cap.
    var cookJournalSheet: some View {
        CookJournalView(
            load: { await viewModel.cookLogs() },
            update: { await viewModel.updateCook($0) }
        )
    }

    /// Log a completed cook then re-derive the current rung. Extracted here so
    /// `FeedView`'s struct body stays under SwiftLint's `type_body_length` cap.
    func logCookAndRefresh(_ entry: CookLogEntry) {
        Task {
            await viewModel.logCook(entry)
            await refreshCurrentRung()
        }
    }
}
