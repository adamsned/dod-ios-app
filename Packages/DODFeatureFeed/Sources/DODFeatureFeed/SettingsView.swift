import DODDesignSystem
import DODFeatureProfile
import DODSupport
import SwiftUI

/// Settings page (US-32 skeleton, US-36 expansion, US-41 iCloud Sync,
/// US-44 Profile, revamped in T-750 / CL-147 + T-752 / CL-149).
///
/// Reached via the gear icon on the trailing edge of the Recipes (Feed)
/// tab's nav bar (see ``FeedView``). The list uses `.insetGrouped` with
/// `.scrollContentBackground(.hidden) + .background(DODColor.surface)`
/// to match the Categories tab treatment (CL-54 / T-560).
///
/// **Section layout (T-752 / CL-149 — top → bottom).** Profile (US-44,
/// no header); **Measurements & Units** (Use Metric Units toggle + Recipe
/// Step Temperatures picker); **Notification Settings** (When New Recipes
/// Drop + When Someone Replies to My Comment toggles); **Customization**
/// (Appearance picker + Cook Mode Voice rows via ``VoiceRows``); **Data &
/// Privacy** (iCloud Sync via ``CloudSyncRows`` + Clear Cached Recipe Images
/// + Share Anonymous Usage Data); About Dutch Oven Daddy; version footer.
/// (DUT-196 moved the former **Tools** ▸ Heat Coach and **Shop** ▸ Buy
/// BuzzyWaxx rows into the Feed's "Cooking Tools" menu, so neither lives in
/// Settings anymore.)
///
/// Section subheaders use `DODType.heading` + primary `DODColor.label`
/// (T-751 / CL-148) so they read distinctly above the `caption` +
/// `labelSecondary` footers. All row labels + headers are Title Case
/// (T-750); footers stay sentence case. The "Default Share Format" UI row
/// was removed in T-750 (the ``SettingsViewModel/shareFormat`` preference
/// is retained for the future link+text share).
///
/// Spec trace: US-32 AC-32.1..AC-32.5; US-36 AC-36.1..AC-36.8;
/// US-41 AC-41.3, AC-41.4; US-44; CL-89; CL-147; CL-148; CL-149.
public struct SettingsView: View {

    // `internal` (not `private`) so the `Binding` wrappers in
    // `SettingsView+Bindings.swift` reach it across the file boundary (DUT-307).
    @State var viewModel: SettingsViewModel
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
        VStack(spacing: 0) {
            // T-843 / DUT-261 — shared `DODScreenHeader` (large, left-aligned,
            // `DODColor.label`) instead of a centered inline `.navigationTitle`,
            // so the Settings header matches Recipes / Saved / Search.
            DODScreenHeader("Settings")
            content
        }
        .background(DODColor.surface)
        // DUT-275 — nav bar hidden; the title pins at the top (header above).
        .dodHidesNavBar()
        // T-756 / CL-153 (DUT-62 bug 2) — give the Settings surface its OWN live
        // color scheme. `preferredColorScheme` applied on `RootView` does NOT
        // propagate into an already-presented sheet (the "only updates on reopen"
        // bug); driving it from the now-observable `viewModel.appearance`
        // re-themes the instant the App Appearance picker changes.
        .preferredColorScheme(viewModel.appearance.colorScheme)
        .overlay(alignment: .bottom) {
            snackbarOverlay
        }
        // DUT-6 cause B — pull the latest CloudKit mirror status into the iCloud
        // Sync row's status sublabel when the screen appears. (T-759 / CL-156
        // removed the per-toggle confirmation dialog; the toggle in
        // `CloudSyncRows` now flips directly.)
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
            // T-783 / DUT-89 — hidden on iPad (Profile lives in the
            // sidebar via SidebarProfileRow); kept on iPhone.
            // DUT-238 — account + sign-in (Sign in with Apple, Sign Out, Delete)
            // all live inside the Profile flow now (tap the Profile row →
            // `ProfileEditView`). The former standalone Settings ▸ Account section
            // (US-46) was redundant with that and is removed.
            ProfileSettingsSection(viewModel: viewModel)

            // T-647 / CL-125 — every Section gets `.listRowBackground(DODColor.surfaceElevated)`.

            // MARK: T-750 / CL-147 — Measurements & Units group

            // DUT-56 — the "Use Metric Units" toggle (US-32 AC-32.4) + the
            // "Recipe Step Temperatures" picker (DUT-47) are grouped into
            // one titled section so the two unit-related controls sit
            // together instead of scattered across the page.
            Section {
                // DUT-307 — the "Use Metric Units" flag persists but NO code
                // reads it (whole-repo grep finds no consumer): a dead control
                // that erodes trust. Disable it with a "Coming soon" caption
                // until the ingredient-conversion consumer (DUT-43) lands. The
                // stored property + `useMetricUnitsKey` are retained so the
                // persisted preference survives for that work.
                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    Toggle(isOn: useMetricUnitsBinding) {
                        Text("Use Metric Units")
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.label)
                    }
                    .disabled(true)
                    .accessibilityIdentifier("settings-toggle-metric")

                    Text("Coming soon")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                        .accessibilityIdentifier("settings-toggle-metric-coming-soon")
                }

                Picker(selection: temperaturePreferenceBinding) {
                    ForEach(TemperaturePreference.allCases, id: \.self) { value in
                        Text(value.displayName)
                            .tag(value)
                    }
                } label: {
                    // T-758 / CL-155 (DUT-64) — explicit `\n` so the label is
                    // narrow enough for the value to sit to its RIGHT (not below).
                    Text("Recipe Step\nTemperatures")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-picker-temperature")
            } header: {
                sectionHeader("Measurements & Units")
            } footer: {
                Text("Converts temperatures shown in the steps. \"Recipe Default\" shows them as written.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            .listRowBackground(DODColor.surfaceElevated)

            // MARK: T-750 / CL-147 — Notification Settings group

            // DUT-56 — the renamed recipe-drop toggle (US-36 AC-36.1) +
            // the new "When Someone Replies to My Comment" toggle grouped
            // under one header. The reply toggle persists + secures
            // notification permission now; delivery follows the server-side
            // push trigger (the DUT-15 backend gap).
            Section {
                Toggle(isOn: notificationsEnabledBinding) {
                    Text("When New Recipes Drop")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-toggle-notifications")

                Toggle(isOn: commentReplyNotificationsBinding) {
                    Text("When Someone Replies to My Comment")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-toggle-comment-reply-notifications")
            } header: {
                sectionHeader("Notification Settings")
            } footer: {
                Text("Alerts are delivered on this device only.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            .listRowBackground(DODColor.surfaceElevated)

            // MARK: T-752 / CL-149 — Customization group

            // DUT-58 — Appearance picker + the Cook Mode Voice rows
            // (`VoiceRows`, `SettingsView+Voice.swift`) grouped under one
            // "Customization" header.
            Section {
                Picker(selection: appearanceBinding) {
                    ForEach(AppearancePreference.allCases, id: \.self) { value in
                        Text(value.displayName)
                            .tag(value)
                    }
                } label: {
                    Text("App Appearance")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-picker-appearance")
                LayoutSettingPicker()

                VoiceRows(viewModel: viewModel)
            } header: {
                sectionHeader("Customization")
            } footer: {
                Text(
                    "The Cook Mode voice reads recipe steps aloud. To use a different voice, "
                        + "download one in Settings › Accessibility › Read & Speak › Voices › English."
                )
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            }
            .listRowBackground(DODColor.surfaceElevated)

            // MARK: T-752 / CL-149 — Data & Privacy group

            // DUT-58 — iCloud Sync (`CloudSyncRows`) + Share Anonymous Usage
            // Data + Clear Cached Recipe Images grouped under one "Data &
            // Privacy" header, between Tools and About. The iCloud
            // confirmation alert + status refresh stay on the host body.
            // T-758 / CL-155 (DUT-64) — Clear Cache moved BELOW the telemetry
            // toggle (was above).
            Section {
                CloudSyncRows(viewModel: viewModel)

                Toggle(isOn: telemetryEnabledBinding) {
                    Text("Share Anonymous Usage Data")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-toggle-telemetry")

                Button {
                    Task { await clearImageCacheIfAvailable() }
                } label: {
                    Text("Clear Cached Recipe Images")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.accent)
                }
                .accessibilityIdentifier("settings-button-clear-cache")
            } header: {
                sectionHeader("Data & Privacy")
            } footer: {
                Text(
                    "Saved recipes sync across your devices when iCloud Sync is on. "
                        + "Cached images stay on this device. "
                        + "Anonymous usage data never includes personal information."
                )
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            }
            .listRowBackground(DODColor.surfaceElevated)

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

    // MARK: - Section header

    /// Brand-consistent grouped-section header. A custom `Text` header
    /// (not the `Section("…")` string form) so the brand font + color
    /// apply instead of the system's uppercased grey.
    ///
    /// **T-751 / CL-148 (DUT-57) — header/description hierarchy.** Uses
    /// `DODType.heading` (17pt semibold) + primary `DODColor.label` so
    /// the subheader reads as distinctly larger + bolder than the section
    /// footer descriptions (which stay `DODType.caption` 12pt medium +
    /// `DODColor.labelSecondary`). Pre-T-751 the header matched the footer
    /// (both `caption` + `labelSecondary`), leaving no visual distinction.
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .dodFont(DODType.heading)
            .foregroundStyle(DODColor.label)
    }

    // The SwiftUI `Binding` wrappers (`useMetricUnitsBinding`, etc.) live in
    // `SettingsView+Bindings.swift` so this host file stays under the 400-line
    // `file_length` cap (DUT-307, following the T-738 / CL-134 split pattern).

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
