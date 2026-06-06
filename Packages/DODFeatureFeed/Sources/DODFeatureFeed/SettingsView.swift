import DODDesignSystem
import DODFeatureProfile
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
            // DUT-6 cause B — pull the latest CloudKit mirror status into the
            // iCloud Sync row's status sublabel when the screen appears.
            .task {
                viewModel.refreshCloudSyncStatus()
            }
    }

    @ViewBuilder
    private var content: some View {
        let baseList = List {
            // MARK: US-44 (T-739) — Profile row at the top

            // The Profile section MUST be the first section (above Use
            // Metric Units) per the locked CL-136 / DUT-36 Phase a
            // decision — the user expects "Settings → Profile" to be
            // the first thing they see, matching iOS Settings' "Apple
            // ID" placement. Renders the empty-state "Set up your
            // profile" row when no profile exists; renders the avatar
            // + display name + email row when one does. Tap pushes
            // `ProfileEditView`.
            Section {
                ProfileSettingsRow(viewModel: viewModel)
            }
            .listRowBackground(DODColor.surfaceElevated)

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

            // MARK: DUT-47 (temperature half) — recipe-step temperature unit

            Section {
                Picker(selection: temperaturePreferenceBinding) {
                    ForEach(TemperaturePreference.allCases, id: \.self) { value in
                        Text(value.displayName)
                            .tag(value)
                    }
                } label: {
                    Text("Recipe step temperatures")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-picker-temperature")
            } footer: {
                Text("Converts temperatures shown in the steps. \"Recipe default\" shows them as written.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
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

            // MARK: US-40 / AC-40.10 + AC-40.12 + AC-40.13 — Cook Mode voice
            // section (gender picker + quality readout + Preview + download
            // nudge). The section view lives in `SettingsView+Voice.swift` so
            // this file stays under the file_length cap (T-721 / T-722).
            VoiceSection(viewModel: viewModel)

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

            // MARK: DUT-48 Tools — Dutch Oven Heat Coach

            // The "Tools" section view lives in `SettingsView+Tools.swift`
            // so this file stays under the 400-line `file_length` cap. It
            // pushes ``HeatCoachView`` via the same NavigationLink push
            // pattern as the About row below — a v1 low-risk entry point;
            // a dedicated "Tools" tab is the eventual home (DUT-48).
            ToolsSection()

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

    private var temperaturePreferenceBinding: Binding<TemperaturePreference> {
        Binding(
            get: { viewModel.temperaturePreference },
            set: { viewModel.temperaturePreference = $0 }
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

// `AboutNedView` lives in `AboutNedView.swift` so the host file stays
// under the 400-line `file_length` cap (T-738 / CL-134, DUT-14).
//
// `VoiceGender.displayName` (the Cook Mode voice-picker label) lives in
// `SettingsView+Voice.swift` alongside the `VoiceSection` that renders it
// (T-721) — the same file_length split — so it is intentionally not
// redeclared here.
