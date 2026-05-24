import DODAnalytics
import DODDesignSystem
import SwiftUI

/// Top-level shell. TabView on compact widths (iPhone), NavigationSplitView on
/// iPad regular. Per-tab navigation lives in `TabStack` so each NavigationStack
/// owns its own @State path — that's the fix for DOD-NAV-1.
struct RootView: View {

    @State private var dependencies: AppDependencies
    @State private var selectedTab: AppTab = .feed
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(dependencies: AppDependencies) {
        _dependencies = State(initialValue: dependencies)
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
    }

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
