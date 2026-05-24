import DODAnalytics
import DODDesignSystem
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
        .task { await dependencies.bootstrap() }
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
                TabStack(tab: tab, dependencies: dependencies)
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
            TabStack(tab: selectedTab, dependencies: dependencies)
                .id(selectedTab)
        }
        .tint(DODColor.accent)
        .onChange(of: selectedTab) { _, newValue in
            Telemetry.shared.send(.screenView(name: newValue.telemetryName))
        }
    }
}
