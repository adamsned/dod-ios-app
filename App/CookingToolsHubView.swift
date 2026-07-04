import DODAnalytics
import DODDesignSystem
import DODFeatureFeed
import DODSupport
import SwiftUI

/// T-912 / DUT-551 (CL-306) — a pushable destination inside the Cooking Tools
/// hub's own `NavigationStack`. The only structural destination today is the
/// Shopping List (every other tool is a sheet or a browser hand-off). Kept as
/// its own type — separate from `RecipeRoute` (recipe/category navigation) — so
/// the hub stack stays a clean list of hub-specific pages, mirroring how the
/// Grocery tab kept the Shopping List independent of the article stack.
enum HubDestination: Hashable {
    case shoppingList
}

/// DUT-560 — the cooking tools the hub can be routed to open. `buyBuzzyWaxx` is
/// deliberately NOT here: it opens a store URL (handled in `RootView`), not a
/// hub tool. Drives ``HubToolRoute``.
enum HubTool: Equatable {
    case shoppingList
    case heatCoach
    case cookingJournal
    case firstCookout
    case cookMode
}

/// DUT-560 — one unified reroute request replacing the per-tool tokens
/// (`hubShoppingListToken` / `hubHeatCoachToken`). `RootView` mints a fresh
/// `id` per request so a repeat of the same tool still re-fires; the hub
/// consumes it via `.task(id:)`. All six control-driven tools (plus the deep
/// link, snackbar, cart, and recipe nudge) funnel through this one path.
struct HubToolRoute: Equatable {
    let id: UUID
    let tool: HubTool
}

/// T-912 / DUT-551 (CL-306) — the **Cooking Tools** hub: a first-class tab that
/// lists every utility a cook reaches for, **in meal-making order** (shop →
/// heat → cook → after). It replaces the retired standalone "Cooking Tools"
/// dropdown menu (which was buried in the Feed toolbar), the retired Grocery
/// List tab (the Shopping List is now the pushed row #2 here), and gives each
/// tool a Title-Case title + a sentence-case "what it does + why it matters"
/// description so a newcomer can see everything the app offers in one place.
///
/// **Lives at app level** (not in a feature package) because it reaches views
/// from `DODFeatureFeed` (`CookChooserFlow`, `HeatCoachView`, `CookJournalView`)
/// and reuses `App/GroceryTabRoot.swift` — only the App target imports all the
/// pieces (same precedent as `GroceryTabRoot`).
struct CookingToolsHubView: View {

    let dependencies: AppDependencies

    /// DUT-560 — the unified hub-tool reroute request (replaces the per-tool
    /// `shoppingListToken` / `heatCoachToken`). `RootView` mints a fresh
    /// `HubToolRoute` when ANY hub tool entry point fires — the `dod://` deep
    /// link, the iOS 18 configurable Control Center control, the recipe/card
    /// snackbar "View", the Saved header cart, the per-recipe Heat Coach nudge —
    /// and selects this tab; the hub consumes it via `.task(id:)` (not
    /// `.onChange`, so a cold-launch Control Center request still fires) and
    /// opens the tool. Mirrors the old `openShoppingListToken` pattern (CL-301).
    @Binding var pendingTool: HubToolRoute?

    /// DUT-461 (revised) — the Cooking Tip token. The lock-screen Cooking Tip
    /// widget's tap mints it; the hub consumes it via `.task(id:)` and pops to its
    /// root so the persistent tip banner at the top is visible (the user may have
    /// been pushed into the Shopping List). Owned by `RootView` so it survives the
    /// iPad flip.
    @Binding var tipToken: UUID?

    // The hub's navigation + sheet-presentation state is `internal` (not
    // `private`) so the tool cards extracted to `CookingToolsHubView+ToolCards.swift`
    // (SwiftLint `type_body_length` relief) can drive it across the file boundary.
    /// The hub tab's own navigation stack (Shopping List pushes onto it).
    @State var path: [HubDestination] = []
    /// Presents the "Your First Cookout" roadmap (`CookChooserFlow`).
    @State var showingFirstCookout = false
    /// Presents the Dutch Oven Heat Coach.
    @State var showingHeatCoach = false
    /// Presents the "I Made This" Cooking Journal.
    @State var showingJournal = false
    /// Cook Mode needs a recipe, so its row is an explainer sheet whose CTA
    /// routes the user to the Recipes tab to pick something to cook (never
    /// constructs Cook Mode with a nil `Recipe`).
    @State var showingCookModeExplainer = false

    /// Reused so "Your First Cookout" + the Cooking Journal log/read through the
    /// same store the Feed tab does. Built once from `feedDependencies()` (the
    /// exact seam `FeedView` uses).
    @State private var feedViewModel: FeedViewModel

    /// DUT-559 — the recipe ids the cook has actually logged (DUT-104 journal),
    /// derived from `feedViewModel.cookLogs()`. Passed to `CookChooserFlow` so a
    /// rung the cook already made renders as done (DUT-381) — without this a
    /// brand-new user with no cook history still saw a real recommendation but a
    /// returning cook's out-of-order rungs were never marked cooked.
    @State private var cookedRecipeIDs: Set<Int> = []

    /// DUT-559 / DUT-212 — the cold-launch gate: the recommended rung is only
    /// handed to `CookChooserFlow` once the real cook state has loaded. Before
    /// then `recommended` stays `nil` (the chooser falls through to the plain
    /// roadmap) rather than recommending a stale rung 1 to a returning cook.
    @State private var cookStateLoaded = false

    /// Route the user to the Recipes tab to pick a recipe to cook (the Cook Mode
    /// row's explainer CTA). Injected by `RootView` so this app-level view never
    /// reaches into tab selection directly.
    let onFindRecipe: () -> Void

    /// DUT-551 (CL-306) — opens the Settings sheet from the hub header's trailing
    /// gear (Settings left the tab bar; the gear now lives on every main tab).
    /// Optional so tests / previews that omit it show no gear; production wires
    /// it through `TabStack` → `RootView.showSettingsSheet`.
    let onOpenSettings: (() -> Void)?

    /// System `openURL` (RootView's override). The "Buy BuzzyWaxx" row hands off
    /// to the browser; buzzywaxx.com isn't a DOD recipe link, so the override
    /// falls through to `.systemAction`.
    @Environment(\.openURL) private var openURL

    init(
        dependencies: AppDependencies,
        pendingTool: Binding<HubToolRoute?> = .constant(nil),
        tipToken: Binding<UUID?> = .constant(nil),
        onFindRecipe: @escaping () -> Void = {},
        onOpenSettings: (() -> Void)? = nil
    ) {
        self.dependencies = dependencies
        self._pendingTool = pendingTool
        self._tipToken = tipToken
        self.onFindRecipe = onFindRecipe
        self.onOpenSettings = onOpenSettings
        _feedViewModel = State(
            initialValue: FeedViewModel(dependencies: dependencies.feedDependencies())
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                DODScreenHeader("Cooking Tools") {
                    if let onOpenSettings {
                        DODHeaderGearButton { onOpenSettings() }
                    }
                }
                tipBanner
                toolList
            }
            .background(DODColor.surface)
            .dodHidesNavBar()
            .navigationDestination(for: HubDestination.self) { destination in
                switch destination {
                case .shoppingList:
                    // Reused verbatim from the retired Grocery tab — the same
                    // store-backed Shopping List, opened to the persisted list.
                    GroceryTabRoot(dependencies: dependencies)
                }
            }
        }
        // DUT-560 — consume the unified hub-tool reroute request. `.task(id:)`
        // (not `.onChange`) so a request already set when this tab first mounts —
        // a cold-launch Control Center tap, or the deep link that selected the
        // tab before the hub rendered — still opens the tool. A nil request is a
        // no-op. The Shopping List branch PRESERVES the exact crash-fixed push
        // (guarded so a repeat request doesn't double-stack the list).
        .task(id: pendingTool) {
            guard let pendingTool else { return }
            switch pendingTool.tool {
            case .shoppingList:
                if path.last != .shoppingList { path.append(.shoppingList) }
            case .heatCoach:
                showingHeatCoach = true
            case .cookingJournal:
                showingJournal = true
            case .firstCookout:
                showingFirstCookout = true
            case .cookMode:
                showingCookModeExplainer = true
            }
            self.pendingTool = nil
        }
        // DUT-461 (revised) — the Cooking Tip widget's tap mints `tipToken`; pop the
        // hub to its root so the persistent tip banner at the top is visible (the
        // user may have been pushed into the Shopping List). `.task(id:)` so a token
        // set before the tab mounts still fires. A nil token is a no-op.
        .task(id: tipToken) {
            guard tipToken != nil else { return }
            path.removeAll()
            tipToken = nil
        }
        // DUT-559 — load the cook state (the DUT-104 journal's recipe ids) so the
        // guided chooser recommends the cook's REAL next rung and marks the rungs
        // they've already made as done (re-activating DUT-212 + DUT-381, stranded
        // by the DUT-551 hub refactor). `.task` runs once when the hub mounts.
        .task { await loadCookState() }
        .sheet(
            isPresented: $showingFirstCookout,
            // Reload the cook state after the cookout sheet closes: the cook may
            // have logged a rung in the flow, which advances the recommendation.
            onDismiss: {
                feedViewModel.cookoutFlowDidDismiss()
                Task { await loadCookState() }
            },
            content: {
                CookChooserFlow(
                    // DUT-559 / DUT-212 — hand the real recommended rung only once
                    // the cook state has loaded (the cold-launch gate); before then
                    // `nil` falls through to the plain roadmap rather than a stale
                    // rung 1. `cookedRecipeIDs` is ALWAYS the real set so a fresh
                    // cook's rungs aren't all painted done (DUT-381).
                    recommended: cookStateLoaded
                        ? GuidedCookout.nextUncookedRung(cookedRecipeIDs: cookedRecipeIDs)
                        : nil,
                    cookedRecipeIDs: cookedRecipeIDs,
                    onLogCook: { entry in
                        Task { await feedViewModel.logCook(entry) }
                    }
                )
                .onAppear { feedViewModel.cookoutFlowWillPresent() }
            }
        )
        // Celebration — a logged cook that graduates the First Cookout path or
        // bumps a rank fires the moment, once the cookout sheet closes (the hub
        // now owns the flow that logs the cook, so it owns this sheet too).
        .sheet(
            item: Binding(
                get: { feedViewModel.celebration },
                set: { if $0 == nil { feedViewModel.dismissCelebration() } }
            )
        ) { celebration in
            CookCelebrationView(celebration: celebration) { feedViewModel.dismissCelebration() }
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingHeatCoach) {
            NavigationStack { HeatCoachView() }
        }
        .sheet(isPresented: $showingJournal) {
            CookJournalView(
                load: { await feedViewModel.cookLogs() },
                update: { await feedViewModel.updateCook($0) },
                delete: { await feedViewModel.deleteCook($0) }
            )
        }
        .sheet(isPresented: $showingCookModeExplainer) {
            cookModeExplainer
        }
    }

    // MARK: - The tool list

    // The six tool cards + the `toolCard` builder live in
    // `CookingToolsHubView+ToolCards.swift` so this host type stays under the
    // SwiftLint `type_body_length` cap (mirrors the `+TipBanner.swift` split).

    /// Cook Mode can't launch without a recipe, so this row's sheet explains the
    /// flow and routes the user to the Recipes tab to pick something to cook.
    private var cookModeExplainer: some View {
        NavigationStack {
            VStack(spacing: DODSpacing.lg) {
                Image(systemName: "flame.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(DODColor.burntOrange)
                Text("Cook Mode")
                    .dodFont(DODType.displayMedium)
                    .foregroundStyle(DODColor.labelStrong)
                Text(
                    "Cook Mode walks you through a recipe hands-free, one step at a time, "
                        + "with timers and voice. Open any recipe and tap Cook Now to start."
                )
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                Button {
                    showingCookModeExplainer = false
                    onFindRecipe()
                } label: {
                    Text("Find a Recipe")
                        .frame(maxWidth: .infinity)
                }
                .dodProminentButton()
                .accessibilityIdentifier("hub-cook-mode-find-recipe")
            }
            .padding(DODSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(DODColor.surface)
            .navigationTitle("")
            .dodInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingCookModeExplainer = false }
                        .tint(DODColor.burntOrange)
                }
            }
        }
        .presentationDetents([.medium])
    }

    /// Hand a tool URL (the BuzzyWaxx storefront) to the browser. Built with
    /// `if let` from the `String` constant so the repo's `force_unwrapping`
    /// lint stays clean (mirrors the retired Feed menu's helper). `internal` (not
    /// `private`) so the `+ToolCards.swift` extension's Buy BuzzyWaxx card can
    /// reach it across the file boundary.
    func openToolURL(_ string: String) {
        if let url = URL(string: string) {
            openURL(url)
        }
    }

    /// DUT-559 — load the logged cooks (the DUT-104 journal) into `cookedRecipeIDs`
    /// and flip `cookStateLoaded`, so the guided chooser recommends the cook's real
    /// next rung and marks already-made rungs done. Reads through the same
    /// `feedViewModel.cookLogs()` seam the Journal uses; a failure yields an empty
    /// set (a brand-new cook), which recommends rung 1 once loaded.
    private func loadCookState() async {
        let logs = await feedViewModel.cookLogs()
        cookedRecipeIDs = Set(logs.map(\.recipeID))
        cookStateLoaded = true
    }
}
