import DODDesignSystem
import DODFeatureFeed
import DODFeatureProfile
import SwiftUI

/// `RootView`'s two top-level layouts, extracted from `RootView.swift` to keep it
/// under the SwiftLint `file_length` cap (the same split the deep-link routing and
/// appearance extensions already use).
///
/// The pair is the reason the First Cookout callout is iPhone-only: `phoneTabs` is
/// a `TabView` with a real bottom tab bar for the callout's tail to point at, while
/// `iPadSplit`'s tabs are `NavigationSplitView` SIDEBAR ROWS — there is no bottom
/// tab bar there at all.
extension RootView {

    var phoneTabs: some View {
        TabView(selection: tabSelection) {
            ForEach(AppTab.allCases) { tab in
                TabStack(
                    tab: tab,
                    dependencies: dependencies,
                    path: pathBinding(for: tab),
                    pendingDeepLink: tab == .feed ? $pendingDeepLink : .constant(nil),
                    externalRoute: externalRouteBinding(for: tab),
                    // T-912/DUT-551 — Shopping List entry points reroute to the
                    // hub; the gear opens Settings; Cook Mode routes to Recipes.
                    openShoppingList: { routeToShoppingList() },
                    onOpenSettings: { showSettingsSheet = true },
                    onFindRecipe: { findRecipeToCook() },
                    // T-912/DUT-551 — the per-recipe Heat Coach nudge routes here.
                    openHeatCoach: { seed in routeToHeatCoach(seed: seed) },
                    hubPendingTool: tab == .cookingTools ? $hubPendingTool : .constant(nil),
                    hubTipToken: tab == .cookingTools ? $hubTipToken : .constant(nil),
                    cookModeFindRecipeArmed: tab == .feed ? $cookModeFindRecipeArmed : .constant(false),
                    // DUT-546 — one shared moderation store across every recipe screen.
                    commentModeration: commentModeration
                )
                // The First Cookout callout, attached to the Feed tab INSIDE the
                // TabView so it (a) only ever shows on Feed and (b) picks up the
                // tab bar as its bottom safe area, landing just above it. See
                // `RootView+FirstCookoutCallout.swift`.
                .overlay(alignment: .bottom) {
                    if tab == .feed { firstCookoutCallout }
                }
                .tabItem {
                    // T-660 / CL-65: bottom-tab `Label` reads `tabLabel` (short —
                    // "Recipes" for `.feed`) so the ~80pt fixed-width tab-bar slot
                    // doesn't truncate the "Recipes & Articles" rename. The
                    // screen-header `navigationTitle` still renders the full `title`.
                    Label(tab.tabLabel, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .tint(DODColor.accent)
        .sensoryFeedback(.selection, trigger: selectedTab)
        // Re-read the cook state whenever the user lands back on Feed, so a cook
        // who just graduated the last rung (in the hub) doesn't come back to a
        // stale callout. `.task(id:)` re-runs on every tab change; the loaded flag
        // stays true across reloads, so the bubble never flashes mid-refresh.
        .task(id: selectedTab) {
            guard selectedTab == .feed else { return }
            await loadFirstCookoutCalloutState()
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.25),
            value: firstCookoutCalloutDismissed
        )
        .modifier(ScreenViewTracking(selectedTab: selectedTab, lastEmittedTab: $lastEmittedTab))
    }

    var iPadSplit: some View {
        let selectionBinding = Binding<AppTab?>(
            get: { selectedTab },
            set: { selectedTab = $0 ?? selectedTab }
        )
        return NavigationSplitView {
            List(selection: selectionBinding) {
                // T-783 / DUT-89 — Profile pinned at the top of the sidebar
                // (moved from Settings on iPad). Untagged, so it's not a tab
                // selection target — its Button opens the editor as a sheet.
                Section {
                    SidebarProfileRow(
                        profileStore: dependencies.profileStore,
                        profilePhotoStore: dependencies.profilePhotoStore,
                        accountTeardownExtras: accountTeardownExtras,
                        // DUT-607 — feed the same stats-backing VM the iPhone
                        // Settings profile uses so the iPad sidebar profile shows
                        // the Cook Rank / counts / Cooking Journal section too.
                        settingsViewModel: dependencies.settingsSheetViewModel(
                            accountTeardownExtras: accountTeardownExtras
                        )
                    )
                }
                Section {
                    ForEach(AppTab.allCases) { tab in
                        Label(tab.title, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                    // Untagged Settings row (T-912/DUT-551, like `SidebarProfileRow`) → gear's sheet.
                    Button {
                        showSettingsSheet = true
                    } label: {
                        // DUT — accent on the gear ICON only (icon/pill/small-fill); text stays default.
                        Label {
                            Text("Settings")
                        } icon: {
                            Image(systemName: "gearshape").foregroundStyle(DODColor.accent)
                        }
                    }
                    .accessibilityIdentifier("sidebar-settings-row")
                }
            }
            // T-784 / DUT-90 — no brand title in the sidebar. The pinned Profile
            // row reads as the header, so a "Dutch Oven Daddy" large title just
            // crowds it; empty + inline collapses the band so Profile rises to top.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.sidebar)
        } detail: {
            // Re-instantiate per tab change so @State in TabStack resets cleanly.
            TabStack(
                tab: selectedTab,
                dependencies: dependencies,
                path: pathBinding(for: selectedTab),
                pendingDeepLink: selectedTab == .feed ? $pendingDeepLink : .constant(nil),
                externalRoute: externalRouteBinding(for: selectedTab),
                // T-912/DUT-551 — Shopping List reroute + hub Cook Mode → Recipes.
                openShoppingList: { routeToShoppingList() },
                // DUT-563 — wire the header gear on iPad too (else it's a dead button).
                onOpenSettings: { showSettingsSheet = true },
                onFindRecipe: { findRecipeToCook() },
                // T-912/DUT-551 — the per-recipe Heat Coach nudge routes here.
                openHeatCoach: { seed in routeToHeatCoach(seed: seed) },
                hubPendingTool: selectedTab == .cookingTools ? $hubPendingTool : .constant(nil),
                hubTipToken: selectedTab == .cookingTools ? $hubTipToken : .constant(nil),
                cookModeFindRecipeArmed: selectedTab == .feed ? $cookModeFindRecipeArmed : .constant(false),
                // DUT-546 — one shared moderation store across every recipe screen.
                commentModeration: commentModeration
            )
            .id(selectedTab)
        }
        .tint(DODColor.accent)
        .modifier(ScreenViewTracking(selectedTab: selectedTab, lastEmittedTab: $lastEmittedTab))
    }
}
