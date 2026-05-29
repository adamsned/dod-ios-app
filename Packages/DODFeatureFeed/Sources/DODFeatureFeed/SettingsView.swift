import DODDesignSystem
import SwiftUI

/// Settings page (US-32 skeleton, US-36 expansion).
///
/// Reached via the gear icon on the trailing edge of the Recipes (Feed)
/// tab's nav bar (see ``FeedView``). The list uses `.insetGrouped` with
/// `.scrollContentBackground(.hidden) + .background(DODColor.surface)`
/// to match the Categories tab treatment (CL-54 / T-560).
///
/// **US-32 (T-550 skeleton) rows:**
///   1. Use metric units — `Toggle` bound to ``SettingsViewModel/useMetricUnits``
///      (UserDefaults round-trip; T-551 follow-up wires consumption).
///   2. About Dutch Oven Daddy — `NavigationLink` to a placeholder
///      destination (T-552 follow-up swaps in the WP REST fetch).
///   3. Version footer.
///
/// **US-36 (T-630 expansion) rows:**
///   4. Notifications — `Toggle` bound to
///      ``SettingsViewModel/notificationsEnabled`` (UI-only in v1;
///      T-631 follow-up requests APNs authorization).
///   5. Appearance — `Picker` bound to ``SettingsViewModel/appearance``.
///      Selection persists and `RootView.preferredColorScheme(...)`
///      consumes the persisted value at launch.
///   6. Default Share Format — `Picker` bound to
///      ``SettingsViewModel/shareFormat``. Persisted now; a future task
///      wires the consumer at the `ShareLink` call site.
///   7. Clear Cached Recipe Images — `Button` that invokes
///      ``SettingsViewModel/clearImageCache(via:)`` and surfaces a
///      `Snackbar` with the freed-MB count.
///   8. Share Anonymous Usage Data — `Toggle` bound to
///      ``SettingsViewModel/telemetryEnabled`` (default ON);
///      `TelemetryDeckTransport` reads the same key at every `send(_:)`
///      and short-circuits when false.
///
/// Spec trace: US-32 AC-32.1..AC-32.5; US-36 AC-36.1..AC-36.8.
public struct SettingsView: View {

    @State private var viewModel: SettingsViewModel
    /// Closure the Clear Cache row delegates to. Returns the total
    /// bytes freed so the snackbar can format the "Freed X.X MB" copy.
    /// Optional so previews + snapshot tests don't need to plumb a
    /// `RecipeStore` — the button surfaces the zero-bytes copy when
    /// nil. Production callers (composition root, FeedView's gear icon)
    /// always pass a non-nil closure.
    public let onClearImageCache: (() async throws -> Int)?

    /// Fires the two sample local notifications behind the temporary DEBUG
    /// "Simulate New Post" affordance (US-42 / AC-42.6). Supplied by the
    /// composition root (routes through `NotificationService`); `nil` in
    /// previews / snapshot hosts so the button is a no-op there. The
    /// toggle-off suppression (AC-42.4) lives inside the closure's
    /// `NotificationService` call, not here — the button always delegates.
    public let onSimulateNewPosts: (() -> Void)?

    public init(
        viewModel: SettingsViewModel = SettingsViewModel(),
        onClearImageCache: (() async throws -> Int)? = nil,
        onSimulateNewPosts: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onClearImageCache = onClearImageCache
        self.onSimulateNewPosts = onSimulateNewPosts
    }

    public var body: some View {
        content
            .navigationTitle("Settings")
            #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
            #endif
            .overlay(alignment: .bottom) {
                snackbarOverlay
            }
    }

    @ViewBuilder
    private var content: some View {
        let baseList = List {
            // MARK: US-32 rows

            Section {
                Toggle(isOn: useMetricUnitsBinding) {
                    Text("Use metric units")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-toggle-metric")
            }

            // MARK: US-36 rows

            Section {
                Toggle(isOn: notificationsEnabledBinding) {
                    Text("Notify me when new recipes drop")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-toggle-notifications")

                #if DEBUG
                // Temporary developer affordance (US-42 / AC-42.6) — fires
                // two sample local notifications (one article, one recipe)
                // ~2s apart so the end-to-end path can be exercised in the
                // simulator (v1 has no server trigger). Gated by the toggle:
                // the `NotificationService` behind `onSimulateNewPosts`
                // schedules nothing when notifications are OFF (AC-42.4).
                // `#if DEBUG` so it never ships in a release build.
                Button {
                    onSimulateNewPosts?()
                } label: {
                    Text("▸ Test: Simulate New Post")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.accent)
                }
                .accessibilityIdentifier("settings-button-simulate-notification")
                #endif
            } footer: {
                Text("New-post alerts are delivered on this device only.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }

            Section {
                Picker(selection: appearanceBinding) {
                    ForEach(AppearancePreference.allCases, id: \.self) { value in
                        Text(value.displayName)
                            .tag(value)
                    }
                } label: {
                    Text("Appearance")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-picker-appearance")
            }

            Section {
                Picker(selection: shareFormatBinding) {
                    ForEach(ShareFormatPreference.allCases, id: \.self) { value in
                        Text(value.displayName)
                            .tag(value)
                    }
                } label: {
                    Text("Default share format")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-picker-share-format")
            }

            Section {
                Button {
                    Task { await clearImageCacheIfAvailable() }
                } label: {
                    Text("Clear Cached Recipe Images")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.accent)
                }
                .accessibilityIdentifier("settings-button-clear-cache")
            } footer: {
                Text("Saved recipe images stay on your device.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }

            Section {
                Toggle(isOn: telemetryEnabledBinding) {
                    Text("Share anonymous usage data")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-toggle-telemetry")
            } footer: {
                Text("Helps us improve the app. No personal information leaves your device.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }

            // MARK: US-32 About + version

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

    /// Snackbar overlay for the cache-clear feedback (AC-36.4). Hidden
    /// when the view-model has no message; auto-dismisses on tap.
    @ViewBuilder
    private var snackbarOverlay: some View {
        if let message = viewModel.snackbarMessage {
            Snackbar(message: message)
                .padding(.bottom, DODSpacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture { viewModel.dismissSnackbar() }
                .task {
                    // Auto-dismiss after 4 seconds. Matches the Snackbar
                    // component's documented default presentation length.
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    viewModel.dismissSnackbar()
                }
                .accessibilityIdentifier("settings-snackbar")
        }
    }

    // MARK: - Bindings

    /// Wraps each view-model property in a SwiftUI Binding so the
    /// Toggle / Picker drives it without exposing the @Observable
    /// mutation directly to the view layer.

    private var useMetricUnitsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.useMetricUnits },
            set: { viewModel.useMetricUnits = $0 }
        )
    }

    private var notificationsEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.notificationsEnabled },
            // Turning ON requests system authorization (US-42 / AC-42.1);
            // a denied prompt leaves the persisted flag OFF so the toggle
            // springs back. The work is async (the system prompt), so it
            // runs in a Task — the `@Observable` `notificationsEnabled`
            // write inside `setNotificationsEnabled` re-renders the toggle.
            set: { newValue in
                Task { await viewModel.setNotificationsEnabled(newValue) }
            }
        )
    }

    private var appearanceBinding: Binding<AppearancePreference> {
        Binding(
            get: { viewModel.appearance },
            set: { viewModel.appearance = $0 }
        )
    }

    private var shareFormatBinding: Binding<ShareFormatPreference> {
        Binding(
            get: { viewModel.shareFormat },
            set: { viewModel.shareFormat = $0 }
        )
    }

    private var telemetryEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.telemetryEnabled },
            set: { viewModel.telemetryEnabled = $0 }
        )
    }

    // MARK: - Actions

    private func clearImageCacheIfAvailable() async {
        guard let onClearImageCache else {
            // No closure wired (preview / snapshot host). Surface the
            // zero-case copy so the button still gives feedback rather
            // than appearing broken in design surfaces.
            viewModel.previewCacheClearMessage()
            return
        }
        await viewModel.clearImageCache(onClear: onClearImageCache)
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
