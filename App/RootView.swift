import CoreSpotlight
import DODAnalytics
import DODDesignSystem
import DODSupport
import SwiftUI

/// Top-level shell. TabView on compact widths (iPhone), NavigationSplitView on
/// iPad regular. Per-tab navigation lives in `TabStack` so each NavigationStack
/// owns its own @State path — that's the fix for DOD-NAV-1.
struct RootView: View {

    /// `UserDefaults` key that gates the first-launch welcome sheet. Persisted
    /// as a bool — `true` once the user dismisses the sheet, never set again.
    /// The `V1` suffix is intentional: if we ever want to re-show onboarding
    /// after a major redesign we bump to `V2` rather than reading the old key.
    /// Spec trace: US-8 (post-launch amendment to CL-7).
    static let onboardingCompletedKey = "dod.onboardingCompletedV1"

    @State private var dependencies: AppDependencies
    @State private var selectedTab: AppTab = .feed
    @State private var showOnboarding: Bool
    /// Widget deep link (spec.md US-9 AC-9.2). Feed tab consumes via .task(id:).
    @State private var pendingDeepLink: WidgetDeepLink?
    /// App Intents / Spotlight route (spec.md US-10).
    @State private var feedExternalRoute: RecipeRoute?
    @State private var dispatcher = DeepLinkDispatcher.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(dependencies: AppDependencies) {
        _dependencies = State(initialValue: dependencies)
        _showOnboarding = State(
            initialValue: !UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey)
        )
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadSplit
            } else {
                phoneTabs
            }
        }
        .task {
            await dependencies.bootstrap()
            // Push current saved + recents into Spotlight on every cold launch
            // so users can find DOD recipes from the home-screen search bar
            // even if they've never invoked the app today (US-10 / AC-10.3).
            await indexSpotlight()
        }
        .onOpenURL { url in
            // Widget deep links route through WidgetDeepLink; App-Intents URLs
            // route through DeepLinkIntent. Try widget first (narrower), then
            // intent fallback.
            if let link = WidgetDeepLink(url: url) {
                handle(widgetLink: link)
                return
            }
            if let intent = DeepLinkIntent.parse(url) {
                handle(intent: intent)
            }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard
                let identifier = activity.userInfo?[
                    CSSearchableItemActivityIdentifier
                ] as? String,
                let id = identifier.split(separator: ".").last.flatMap({ Int($0) })
            else { return }
            handle(intent: .openRecipe(id: id))
        }
        .onChange(of: dispatcher.pending) { _, newValue in
            guard let newValue else { return }
            handle(intent: newValue)
            dispatcher.consume()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet(
                title: "Welcome to Dutch Oven Daddy",
                bullets: Self.welcomeBullets,
                ctaTitle: "Get cooking",
                onContinue: {
                    UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
                    showOnboarding = false
                }
            )
            .presentationDetents([.large])
        }
    }

    /// The three highlight rows shown on first launch. Declared as a static so
    /// the array is not rebuilt every render and so tests/previews can reuse
    /// the exact same content the app ships.
    static let welcomeBullets: [OnboardingSheet.Bullet] = [
        .init(
            systemImage: "house.fill",
            title: "Browse the latest",
            caption: "New cast iron recipes appear at the top."
        ),
        .init(
            systemImage: "magnifyingglass",
            title: "Search what you've got",
            caption: "Type any ingredient or technique to filter."
        ),
        .init(
            systemImage: "heart.fill",
            title: "Save for offline",
            caption: "Tap the heart on any recipe to cook it without Wi-Fi."
        ),
    ]

    private var phoneTabs: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                TabStack(
                    tab: tab,
                    dependencies: dependencies,
                    pendingDeepLink: tab == .feed ? $pendingDeepLink : .constant(nil),
                    externalRoute: tab == .feed ? $feedExternalRoute : .constant(nil)
                )
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .tint(DODColor.accent)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .onChange(of: selectedTab) { _, newValue in
            Telemetry.shared.send(.screenView(name: newValue.telemetryName))
        }
        .onAppear {
            Telemetry.shared.send(.screenView(name: AppTab.feed.telemetryName))
        }
    }

    private var iPadSplit: some View {
        let selectionBinding = Binding<AppTab?>(
            get: { selectedTab },
            set: { selectedTab = $0 ?? selectedTab }
        )
        return NavigationSplitView {
            List(selection: selectionBinding) {
                ForEach(AppTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .navigationTitle("DOD")
            .listStyle(.sidebar)
        } detail: {
            // Re-instantiate per tab change so @State in TabStack resets cleanly.
            TabStack(
                tab: selectedTab,
                dependencies: dependencies,
                pendingDeepLink: selectedTab == .feed ? $pendingDeepLink : .constant(nil),
                externalRoute: selectedTab == .feed ? $feedExternalRoute : .constant(nil)
            )
            .id(selectedTab)
        }
        .tint(DODColor.accent)
        .onChange(of: selectedTab) { _, newValue in
            Telemetry.shared.send(.screenView(name: newValue.telemetryName))
        }
    }

    // MARK: - Deep-link routing

    /// Widget URL handler (spec.md US-9 AC-9.2). Switches to Feed and
    /// hands the link to TabStack via the `pendingDeepLink` binding.
    private func handle(widgetLink link: WidgetDeepLink) {
        selectedTab = .feed
        pendingDeepLink = link
    }

    /// Routes a parsed `DeepLinkIntent` into tab + path state (US-10).
    private func handle(intent: DeepLinkIntent) {
        switch intent {
        case .openSaved:
            selectedTab = .saved
        case .openRecipe(let id):
            selectedTab = .feed
            Task { @MainActor in
                guard let route = await resolveRecipeRoute(id: id, autoStartCookMode: false) else {
                    return
                }
                feedExternalRoute = route
            }
        case .startCookMode(let recipeID):
            selectedTab = .feed
            Task { @MainActor in
                guard
                    let route = await resolveRecipeRoute(
                        id: recipeID,
                        autoStartCookMode: true
                    )
                else { return }
                feedExternalRoute = route
            }
        }
    }

    private func resolveRecipeRoute(id: Int, autoStartCookMode: Bool) async -> RecipeRoute? {
        guard let recipe = try? await dependencies.store.recipeWithoutTouching(id: id) else {
            DODLog.app.error("deep link: recipe \(id) not in cache, ignoring")
            return nil
        }
        let item = RecipeEntityPayload.fromRecipe(recipe).toListItem()
        return .recipe(item: item, autoStartCookMode: autoStartCookMode)
    }

    private func indexSpotlight() async {
        do {
            let payloads = try await RecipeEntityQuery.suggestedPayloads()
            let items = payloads.map { payload -> CSSearchableItem in
                let entity = RecipeEntity(payload: payload)
                return CSSearchableItem(
                    uniqueIdentifier: "dod.recipe.\(payload.id)",
                    domainIdentifier: "com.dutchovendaddy.DODApp.recipes",
                    attributeSet: entity.attributeSet
                )
            }
            try await CSSearchableIndex.default().indexSearchableItems(items)
        } catch {
            DODLog.app.error("spotlight index failed: \(String(describing: error))")
        }
    }
}
