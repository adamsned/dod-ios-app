import DODDesignSystem
import DODSupport
import SwiftUI

/// Settings page (US-32 skeleton, US-36 expansion, US-41 iCloud Sync row).
///
/// Reached via the gear icon on the trailing edge of the Recipes (Feed)
/// tab's nav bar (see ``FeedView``). The list uses `.insetGrouped` with
/// `.scrollContentBackground(.hidden) + .background(DODColor.surface)`
/// to match the Categories tab treatment (CL-54 / T-560).
///
/// **US-32 (T-550 skeleton) rows:**
///   1. Use metric units — `Toggle` bound to ``SettingsViewModel/useMetricUnits``
///      (UserDefaults round-trip; T-551 follow-up wires consumption).
///   2. About Dutch Oven Daddy — `NavigationLink` to ``AboutNedView``
///      (the embedded DUT-14 copy + Ned's photo bundled as a local
///      asset per T-738 / CL-134; supersedes the T-552 WP REST fetch
///      plan since the copy is now embedded verbatim, not fetched).
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
/// **US-41 (T-703) iCloud Sync section** (appended below the existing
/// rows per the task scope — the original CL-89 spec called for the row
/// to sit between Notifications and Appearance, but the codebase landed
/// the Settings layout with one row per Section + a footer, so a single
/// extra Section at the bottom matches the visual rhythm without
/// disturbing the established ordering):
///   9. iCloud Sync — `Toggle` bound to
///      ``SettingsViewModel/isCloudSyncEnabled``. Subtext flips based on
///      state (off: stays-on-device copy; on: across-devices copy).
///      Toggling flips fire a confirmation alert per CL-89.
///  10. Status — read-only row, only visible when the toggle is ON.
///      Renders ``SettingsViewModel/cloudSyncStatusText`` which today
///      returns "Idle"; T-705 wires the real `CloudKitSyncStatus`
///      enum + "Last synced N ago" formatting.
///
/// Spec trace: US-32 AC-32.1..AC-32.5; US-36 AC-36.1..AC-36.8;
/// US-41 AC-41.3, AC-41.4; CL-89 (opt-in flow + confirmation alerts).
public struct SettingsView: View {

    @State private var viewModel: SettingsViewModel
    /// Closure the Clear Cache row delegates to. Returns the total
    /// bytes freed so the snackbar can format the "Freed X.X MB" copy.
    /// Optional so previews + snapshot tests don't need to plumb a
    /// `RecipeStore` — the button surfaces the zero-bytes copy when
    /// nil. Production callers (composition root, FeedView's gear icon)
    /// always pass a non-nil closure.
    public let onClearImageCache: (() async throws -> Int)?

    public init(
        viewModel: SettingsViewModel? = nil,
        onClearImageCache: (() async throws -> Int)? = nil,
        settingsDependencies: (any SettingsDependencies)? = nil
    ) {
        // Construct a default view-model when none is injected,
        // honoring the optional `settingsDependencies` so the iCloud
        // Sync seam (US-41 / AC-41.3) wires through to the composition
        // root's `LiveSettingsDependencies` without forcing every
        // caller to materialize a `SettingsViewModel` up-front.
        let resolved = viewModel ?? SettingsViewModel(dependencies: settingsDependencies)
        _viewModel = State(initialValue: resolved)
        self.onClearImageCache = onClearImageCache
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
            // US-41 AC-41.3 — toggle-flip confirmation alert. The
            // modifier lives in `SettingsView+CloudSync.swift` so this
            // file stays under the file_length cap; the copy + button
            // styles flip with the request direction per CL-89.
            .cloudSyncConfirmationAlert(viewModel: viewModel)
    }

    @ViewBuilder
    private var content: some View {
        let baseList = List {
            // MARK: US-32 rows

            // T-647 / CL-125 — every Section gets `.listRowBackground(DODColor.surfaceElevated)`
            // so the Settings cells render in the brand brown (matches the
            // Recipe & Articles card surface) instead of the system default
            // near-black `secondarySystemGroupedBackground` in dark mode.

            Section {
                Toggle(isOn: useMetricUnitsBinding) {
                    Text("Use metric units")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-toggle-metric")
            }
            .listRowBackground(DODColor.surfaceElevated)

            // MARK: US-36 rows

            Section {
                Toggle(isOn: notificationsEnabledBinding) {
                    Text("Notify me when new recipes drop")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-toggle-notifications")
            } footer: {
                Text("New-post alerts are delivered on this device only.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            .listRowBackground(DODColor.surfaceElevated)

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
            .listRowBackground(DODColor.surfaceElevated)

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
            .listRowBackground(DODColor.surfaceElevated)

            // MARK: US-40 / AC-40.10 — Cook Mode voice picker (T-721)

            Section {
                Picker(selection: voiceGenderBinding) {
                    ForEach(VoiceGender.allCases, id: \.self) { value in
                        Text(value.displayName)
                            .tag(value)
                    }
                } label: {
                    Text("Cook Mode voice")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-picker-voice-gender")
            } footer: {
                Text("Used when reading recipe steps aloud in Cook Mode.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            .listRowBackground(DODColor.surfaceElevated)

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
            .listRowBackground(DODColor.surfaceElevated)

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
            .listRowBackground(DODColor.surfaceElevated)

            // MARK: US-41 / AC-41.3 / AC-41.4 — iCloud Sync section

            // The section view + the confirmation alert modifier live
            // in `SettingsView+CloudSync.swift` so this file stays under
            // the file_length cap. T-647 — the brand row background is
            // applied inside `CloudSyncSection` since the modifier scope
            // must live with the Section it decorates.
            CloudSyncSection(viewModel: viewModel)

            // MARK: US-32 About + version

            Section {
                NavigationLink {
                    AboutNedView()
                } label: {
                    Text("About Dutch Oven Daddy")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-link-about")
            }
            .listRowBackground(DODColor.surfaceElevated)

            Section {
                EmptyView()
            } footer: {
                Text(SettingsViewModel.versionFooter())
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("settings-version-footer")
            }
            .listRowBackground(DODColor.surfaceElevated)
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

    private var voiceGenderBinding: Binding<VoiceGender> {
        Binding(
            get: { viewModel.voiceGender },
            set: { viewModel.voiceGender = $0 }
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

// MARK: - VoiceGender display labels (T-721)

extension VoiceGender {
    /// User-facing label for the Cook Mode voice picker. Kept in the feature
    /// layer (not `DODSupport`) so the domain model stays free of UI copy —
    /// mirrors how ``AppearancePreference/displayName`` lives beside its view.
    var displayName: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .unspecified: return "No preference"
        }
    }
}

// `AboutNedView` lives in `AboutNedView.swift` so the host file stays
// under the 400-line `file_length` cap (T-738 / CL-134, DUT-14).
