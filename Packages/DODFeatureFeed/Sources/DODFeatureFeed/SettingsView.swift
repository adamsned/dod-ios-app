import DODDesignSystem
import SwiftUI

/// Settings page (US-32, T-550 skeleton).
///
/// Reached via the gear icon on the trailing edge of the Recipes (Feed)
/// tab's nav bar (see ``FeedView``). v1 renders a `.insetGrouped` list
/// styled to match the post-T-560 Categories tab (`.scrollContentBackground(.hidden)`
/// + `.background(DODColor.surface)` — the same brand-surface treatment
/// every other top-level tab uses post-T-520).
///
/// Three rows:
///   1. **Use metric units** — `Toggle` bound to ``SettingsViewModel/useMetricUnits``,
///      which round-trips through `UserDefaults`. T-551 follow-up wires
///      the flag into the ingredient-rendering path.
///   2. **About Dutch Oven Daddy** — `NavigationLink` to a placeholder
///      destination showing a coming-soon message. T-552 follow-up
///      replaces the placeholder with the live `/wp/v2/pages?slug=about-me`
///      fetch + offline cache.
///   3. **Version footer** — Section footer rendering
///      `"v\(version) (\(build))"` from `Bundle.main.infoDictionary`.
///
/// Spec trace: US-32 AC-32.1..AC-32.5.
public struct SettingsView: View {

    @State private var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel = SettingsViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        content
            .navigationTitle("Settings")
            #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
            #endif
    }

    @ViewBuilder
    private var content: some View {
        let baseList = List {
            Section {
                Toggle(isOn: useMetricUnitsBinding) {
                    Text("Use metric units")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-toggle-metric")
            }

            Section {
                NavigationLink {
                    SettingsAboutPlaceholderView()
                } label: {
                    Text("About Dutch Oven Daddy")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-link-about")
            }

            Section {
                EmptyView()
            } footer: {
                Text(SettingsViewModel.versionFooter())
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("settings-version-footer")
            }
        }
        .scrollContentBackground(.hidden)
        .background(DODColor.surface)

        #if os(iOS)
        baseList.listStyle(.insetGrouped)
        #else
        baseList
        #endif
    }

    /// Wraps the view-model's `useMetricUnits` Bool in a SwiftUI Binding
    /// so the `Toggle` can drive it without exposing the @Observable
    /// mutation directly to the view layer.
    private var useMetricUnitsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.useMetricUnits },
            set: { viewModel.useMetricUnits = $0 }
        )
    }
}

/// Placeholder destination for the About Dutch Oven Daddy row.
///
/// T-552 follow-up replaces this with the live WP REST fetch
/// (`/wp/v2/pages?slug=about-me`) + offline cache. Shipping a
/// placeholder rather than wiring the fetch in v1 keeps T-550's PR
/// bounded to the Settings entry-point skeleton per CL-56.
struct SettingsAboutPlaceholderView: View {
    var body: some View {
        VStack(spacing: DODSpacing.md) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 48))
                .foregroundStyle(DODColor.burntOrange)
            Text("About Dutch Oven Daddy")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
            Text("Coming soon — fetched from /about-me/")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DODSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DODColor.surface)
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("settings-about-placeholder")
    }
}
