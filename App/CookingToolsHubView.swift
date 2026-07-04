import DODAnalytics
import DODDesignSystem
import DODFeatureFeed
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

    /// T-912 / DUT-551 — the Shopping List reroute token. `RootView` mints a
    /// fresh UUID when any Shopping List entry point fires (`dod://shopping-list`
    /// deep link, the iOS 18 Control Center control, the recipe/card snackbar
    /// "View", the Saved header cart) and selects this tab; the hub consumes the
    /// token via `.task(id:)` (not `.onChange`, so a cold-launch Control Center
    /// token still fires) and pushes `.shoppingList`. Mirrors the old
    /// `openShoppingListToken` pattern the Saved tab used (CL-301).
    @Binding var shoppingListToken: UUID?

    /// T-912 / DUT-551 — the Heat Coach reroute token. `RootView` mints a fresh
    /// UUID when the per-recipe Heat Coach nudge (Recipe Detail) fires and selects
    /// this tab; the hub consumes it via `.task(id:)` (not `.onChange`, so a token
    /// already set when the tab mounts still fires) and presents Heat Coach as a
    /// sheet — reusing the same `showingHeatCoach` state the hub's row #3 drives.
    @Binding var heatCoachToken: UUID?

    /// DUT-461 (revised) — the Cooking Tip token. The lock-screen Cooking Tip
    /// widget's tap mints it; the hub consumes it via `.task(id:)` and pops to its
    /// root so the persistent tip banner at the top is visible (the user may have
    /// been pushed into the Shopping List). Owned by `RootView` so it survives the
    /// iPad flip.
    @Binding var tipToken: UUID?

    /// The hub tab's own navigation stack (Shopping List pushes onto it).
    @State private var path: [HubDestination] = []
    /// Presents the "Your First Cookout" roadmap (`CookChooserFlow`).
    @State private var showingFirstCookout = false
    /// Presents the Dutch Oven Heat Coach.
    @State private var showingHeatCoach = false
    /// Presents the "I Made This" Cooking Journal.
    @State private var showingJournal = false
    /// Cook Mode needs a recipe, so its row is an explainer sheet whose CTA
    /// routes the user to the Recipes tab to pick something to cook (never
    /// constructs Cook Mode with a nil `Recipe`).
    @State private var showingCookModeExplainer = false

    /// Reused so "Your First Cookout" + the Cooking Journal log/read through the
    /// same store the Feed tab does. Built once from `feedDependencies()` (the
    /// exact seam `FeedView` uses).
    @State private var feedViewModel: FeedViewModel

    /// Route the user to the Recipes tab to pick a recipe to cook (the Cook Mode
    /// row's explainer CTA). Injected by `RootView` so this app-level view never
    /// reaches into tab selection directly.
    let onFindRecipe: () -> Void

    /// System `openURL` (RootView's override). The "Buy BuzzyWaxx" row hands off
    /// to the browser; buzzywaxx.com isn't a DOD recipe link, so the override
    /// falls through to `.systemAction`.
    @Environment(\.openURL) private var openURL

    init(
        dependencies: AppDependencies,
        shoppingListToken: Binding<UUID?> = .constant(nil),
        heatCoachToken: Binding<UUID?> = .constant(nil),
        tipToken: Binding<UUID?> = .constant(nil),
        onFindRecipe: @escaping () -> Void = {}
    ) {
        self.dependencies = dependencies
        self._shoppingListToken = shoppingListToken
        self._heatCoachToken = heatCoachToken
        self._tipToken = tipToken
        self.onFindRecipe = onFindRecipe
        _feedViewModel = State(
            initialValue: FeedViewModel(dependencies: dependencies.feedDependencies())
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                DODScreenHeader("Cooking Tools")
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
        // Consume the Shopping List reroute token. `.task(id:)` (not `.onChange`)
        // so a token already set when this tab first mounts — a cold-launch
        // Control Center tap, or the deep link that selected the tab before the
        // hub rendered — still pushes the list. A nil token is a no-op.
        .task(id: shoppingListToken) {
            guard shoppingListToken != nil else { return }
            if path.last != .shoppingList { path.append(.shoppingList) }
            shoppingListToken = nil
        }
        // T-912 / DUT-551 — consume the Heat Coach reroute token (the per-recipe
        // nudge). `.task(id:)` (not `.onChange`) so a token already set when this
        // tab first mounts still presents. Reuses the same `showingHeatCoach`
        // sheet the hub's row #3 drives. A nil token is a no-op.
        .task(id: heatCoachToken) {
            guard heatCoachToken != nil else { return }
            showingHeatCoach = true
            heatCoachToken = nil
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
        .onAppear { Telemetry.shared.send(.screenView(name: "cooking_tools")) }
        .sheet(
            isPresented: $showingFirstCookout,
            onDismiss: { feedViewModel.cookoutFlowDidDismiss() },
            content: {
                CookChooserFlow(
                    // No progress state at the hub (unlike the Feed's rung-aware
                    // presentation) — the chooser falls through to its plain
                    // roadmap, highlighting the first rung as "start here".
                    recommended: nil,
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

    /// The six tools, in meal-making order (shop → heat → cook → after). Each
    /// row: an icon in a tinted circle + a Title-Case title + a sentence-case
    /// description of what it does and why it matters + a chevron. insetGrouped
    /// `List` matching the Settings / Shopping List treatment.
    private var toolList: some View {
        List {
            Section {
                toolRow(
                    icon: "flame.fill",
                    title: "Your First Cookout",
                    description: "New to Dutch oven cooking? Get coached through a whole cook, "
                        + "start to finish.",
                    accessibilityID: "hub-first-cookout"
                ) { showingFirstCookout = true }

                toolRow(
                    icon: "cart.fill",
                    title: "Shopping List",
                    description: "Turn the recipes you're making into one aisle-sorted list, "
                        + "so you shop in a single loop.",
                    accessibilityID: "hub-shopping-list"
                ) {
                    if path.last != .shoppingList { path.append(.shoppingList) }
                }

                toolRow(
                    icon: "thermometer.medium",
                    title: "Heat Coach",
                    description: "Figure out how many coals your oven needs for any temperature, "
                        + "then adjust by feel.",
                    accessibilityID: "hub-heat-coach"
                ) { showingHeatCoach = true }

                toolRow(
                    icon: "flame.circle.fill",
                    title: "Cook Mode",
                    description: "Cook any recipe hands-free, one step at a time, with timers "
                        + "and voice. Open a recipe and tap Cook Now to start.",
                    accessibilityID: "hub-cook-mode"
                ) { showingCookModeExplainer = true }

                toolRow(
                    icon: "book.closed.fill",
                    title: "Cooking Journal",
                    description: "Log every cook with a photo and notes, and build your streak.",
                    accessibilityID: "hub-journal"
                ) { showingJournal = true }

                toolRow(
                    icon: "bag.fill",
                    title: "Buy BuzzyWaxx",
                    description: "Season and protect your cast iron with the wax we swear by.",
                    accessibilityID: "hub-buy-buzzywaxx"
                ) { openToolURL(SettingsViewModel.buyBuzzyWaxxURLString) }
            } header: {
                Text("Everything you need, in the order you'll use it.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .textCase(nil)
                    .padding(.bottom, DODSpacing.xxs)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DODColor.surface)
    }

    /// One hub tool row: tinted-circle icon + Title-Case title + sentence-case
    /// description + chevron, as a full-width plain button.
    private func toolRow(
        icon: String,
        title: String,
        description: String,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DODSpacing.md) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(DODColor.burntOrange)
                    .frame(width: 40, height: 40)
                    .background(DODColor.burntOrange.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    Text(title)
                        .dodFont(DODType.heading)
                        .foregroundStyle(DODColor.label)
                    Text(description)
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DODSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            .padding(.vertical, DODSpacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }

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
    /// lint stays clean (mirrors the retired Feed menu's helper).
    private func openToolURL(_ string: String) {
        if let url = URL(string: string) {
            openURL(url)
        }
    }
}
