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
    /// DUT-584 — an optional ``HeatCoachSeed`` pre-answers the coach when it's
    /// opened from a recipe (the per-recipe nudge threads the recipe's oven
    /// diameter + derived style + target °F). `nil` for standalone opens (the
    /// hub tile, the deep link, the Control Center control), which keep today's
    /// 12"/even default.
    case heatCoach(seed: HeatCoachSeed?)
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

/// DUT-615 — the single sheet the hub can have up at any moment. The hub used to
/// declare FIVE independent `.sheet` presenters (First Cookout, Celebration,
/// Heat Coach, Journal, Cook Mode explainer); asking to present a second while
/// one was already up dropped it silently (SwiftUI only honors one sheet per
/// presenting anchor). Folding them into one `.sheet(item:)` bound to this enum
/// means exactly one presenter exists, so a new request always replaces (never
/// races) whatever is showing. The `heatCoach` case carries the DUT-584 seed and
/// the `celebration` case carries the DUT-104 payload, preserving each sheet's
/// content verbatim.
enum ActiveHubSheet: Identifiable {
    case firstCookout
    case celebration(CookCelebration)
    case heatCoach(seed: HeatCoachSeed?)
    case cookingJournal
    case cookModeExplainer

    var id: String {
        switch self {
        case .firstCookout: return "firstCookout"
        case .celebration(let celebration): return "celebration-\(celebration.id)"
        case .heatCoach: return "heatCoach"
        case .cookingJournal: return "cookingJournal"
        case .cookModeExplainer: return "cookModeExplainer"
        }
    }
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
    /// DUT-615 — the single active tool sheet (First Cookout, Heat Coach with its
    /// DUT-584 seed, Cooking Journal, or the Cook Mode explainer). Replaces the
    /// four independent `showing…` booleans + `heatCoachSeed`, so only one
    /// presenter exists and a second request replaces rather than races the
    /// first. The Celebration sheet is surfaced separately by ``activeHubSheet``
    /// because it's driven reactively by `feedViewModel.celebration`.
    @State var activeToolSheet: ActiveHubSheet?

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

    /// DUT-572 — gates the header Settings gear to compact width (iPhone). On iPad
    /// (regular width) the sidebar already hosts a Settings row, so the gear is
    /// redundant here.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
                    // DUT-572 — gear only in compact width (iPhone); iPad's sidebar
                    // already has a Settings row, so it's redundant in regular width.
                    if let onOpenSettings, horizontalSizeClass == .compact {
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
            case .heatCoach(let seed):
                activeToolSheet = .heatCoach(seed: seed)
            case .cookingJournal:
                activeToolSheet = .cookingJournal
            case .firstCookout:
                activeToolSheet = .firstCookout
            case .cookMode:
                activeToolSheet = .cookModeExplainer
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
        // DUT-615 — ONE sheet presenter for every hub tool + the celebration, so a
        // second presentation replaces (never silently drops) whatever is up.
        .sheet(item: activeHubSheet, onDismiss: handleHubSheetDismiss) { sheet in
            hubSheet(for: sheet)
        }
    }

    /// DUT-615 — the single sheet the hub presents. The reactive celebration
    /// (`feedViewModel.celebration`, set after logging a cook) takes precedence
    /// over the tool-driven `activeToolSheet`; the setter clears whichever source
    /// backed the currently-shown sheet so a swipe-dismiss unwinds cleanly.
    private var activeHubSheet: Binding<ActiveHubSheet?> {
        Binding(
            get: {
                if let celebration = feedViewModel.celebration {
                    return .celebration(celebration)
                }
                return activeToolSheet
            },
            set: { newValue in
                if newValue == nil {
                    if feedViewModel.celebration != nil {
                        feedViewModel.dismissCelebration()
                    }
                    activeToolSheet = nil
                }
            }
        )
    }

    /// DUT-615 — the per-sheet `onDismiss`. Only First Cookout had dismiss
    /// behavior (reload the cook state, since a rung may have been logged in the
    /// flow, which advances the recommendation); every other sheet dismisses
    /// with no side effect. Keyed on `activeToolSheet` because by the time
    /// `onDismiss` fires the binding has already been cleared.
    private func handleHubSheetDismiss() {
        guard case .firstCookout = activeToolSheet else { return }
        feedViewModel.cookoutFlowDidDismiss()
        Task { await loadCookState() }
    }

    /// DUT-615 — the content for the single hub sheet. Each branch preserves the
    /// exact view, seed, and presentation detents the five separate `.sheet`
    /// modifiers used before the consolidation.
    @ViewBuilder
    private func hubSheet(for sheet: ActiveHubSheet) -> some View {
        switch sheet {
        case .firstCookout:
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
        case .celebration(let celebration):
            // Celebration — a logged cook that graduates the First Cookout path
            // or bumps a rank fires the moment, once the cookout sheet closes.
            CookCelebrationView(celebration: celebration) { feedViewModel.dismissCelebration() }
                .presentationDetents([.medium])
        case .heatCoach(let seed):
            // DUT-584 — open pre-answered when a recipe seeded the route; a
            // standalone open (hub tile / deep link) leaves the seed nil.
            NavigationStack { HeatCoachView(seed: seed) }
        case .cookingJournal:
            CookJournalView(
                load: { await feedViewModel.cookLogs() },
                update: { await feedViewModel.updateCook($0) },
                delete: { await feedViewModel.deleteCook($0) }
            )
        case .cookModeExplainer:
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
                // DUT-597 — a balanced, hugging capsule (matching the app's shared
                // `EmptyState` CTA proportions) instead of the old full-width
                // `.frame(maxWidth: .infinity)`, which stretched the capsule into an
                // awkward short-and-long bar. Explicit horizontal/vertical padding
                // gives it a comfortable height and width that harmonizes with the
                // rest of the hub's design language.
                Button {
                    activeToolSheet = nil
                    onFindRecipe()
                } label: {
                    Text("Find a Recipe")
                        .dodFont(DODType.bodyEmphasized)
                        .padding(.horizontal, DODSpacing.lg)
                        .padding(.vertical, DODSpacing.sm)
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
                    Button("Done") { activeToolSheet = nil }
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
