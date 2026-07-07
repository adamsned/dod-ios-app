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
/// (Appearance picker + Cook Mode Voice rows via ``VoiceRows`` + the DUT-596
/// controls auto-minimize picker); **Data & Privacy** (iCloud Sync
/// via ``CloudSyncRows`` + Clear Cached Recipe Images + Share Anonymous Usage
/// Data + the DUT-679 Privacy Policy link); About Dutch Oven Daddy; version
/// footer. (DUT-196 moved the former **Tools** ▸ Heat Coach and **Shop** ▸ Buy
/// BuzzyWaxx rows into the Feed's "Cooking Tools" menu, off Settings.)
///
/// Section subheaders use `DODType.heading` + primary `DODColor.label`
/// (T-751 / CL-148) so they read distinctly above the `caption` +
/// `labelSecondary` footers. All row labels + headers are Title Case (T-750);
/// footers stay sentence case. The "Default Share Format" UI row was removed in
/// T-750 (the ``SettingsViewModel/shareFormat`` preference is kept).
///
/// Spec trace: US-32 AC-32.1..AC-32.5; US-36 AC-36.1..AC-36.8; US-41 AC-41.3,
/// AC-41.4; US-44; CL-89; CL-147; CL-148; CL-149; DUT-679 (Guideline 5.1.1(i)).
public struct SettingsView: View {

    // `internal` (not `private`) so the `Binding` wrappers in
    // `SettingsView+Bindings.swift` reach it across the file boundary (DUT-307).
    @State var viewModel: SettingsViewModel
    /// DUT-551 (CL-306) — Settings is a sheet; the in-content `DODScreenHeader`
    /// was replaced by a nav-bar back button that dismisses the sheet.
    @Environment(\.dismiss) private var dismiss
    /// DUT-529 — when Reduce Motion is on, the cache-clear snackbar crossfades in
    /// (opacity only) instead of sliding up from the bottom edge (constitution §7).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Closure the Clear Cache row delegates to. Returns the total
    /// bytes freed so the snackbar can format the "Freed X.X MB" copy.
    /// Optional so previews + snapshot tests don't need to plumb a
    /// `RecipeStore` — the button surfaces the zero-bytes copy when
    /// nil. Production callers (composition root, FeedView's gear icon)
    /// always pass a non-nil closure.
    public let onClearImageCache: (() async throws -> Int)?
    /// DUT-572 — hides the top Profile section when true. Injected from RootView's
    /// real device size class because this sheet always reports `.compact` on iPad
    /// (see ``ProfileSettingsSection``); hides on iPad, shows on iPhone.
    private let hidesProfile: Bool

    public init(
        viewModel: SettingsViewModel? = nil,
        onClearImageCache: (() async throws -> Int)? = nil,
        settingsDependencies: (any SettingsDependencies)? = nil,
        hidesProfile: Bool = false
    ) {
        // Construct a default view-model when none is injected,
        // honoring the optional `settingsDependencies` so the iCloud
        // Sync seam (US-41 / AC-41.3) wires through to the composition
        // root's `LiveSettingsDependencies` without forcing every
        // caller to materialize a `SettingsViewModel` up-front.
        let resolved = viewModel ?? SettingsViewModel(dependencies: settingsDependencies)
        _viewModel = State(initialValue: resolved)
        self.onClearImageCache = onClearImageCache
        self.hidesProfile = hidesProfile
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(DODColor.surface)
        // DUT-551 (CL-306) — Settings is now a pushed-feeling sheet: an inline
        // nav title + a leading back button (below) that dismisses it, replacing
        // the big in-content `DODScreenHeader`. The sheet's nav bar shows (no
        // `dodHidesNavBar()`).
        .navigationTitle("Settings")
        .dodInlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                // `.cancellationAction` (not `.topBarLeading`) is cross-platform,
                // so this compiles on the macOS L1 `swift test` for this package.
                Button {
                    dismiss()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .tint(DODColor.burntOrange)
                .accessibilityIdentifier("settings-back")
            }
        }
        // T-756 / CL-153 (DUT-62 bug 2) — give the Settings surface its OWN live
        // color scheme. `preferredColorScheme` applied on `RootView` does NOT
        // propagate into an already-presented sheet (the "only updates on reopen"
        // bug); driving it from the now-observable `viewModel.appearance`
        // re-themes the instant the App Appearance picker changes.
        .preferredColorScheme(viewModel.appearance.colorScheme)
        .overlay(alignment: .bottom) {
            snackbarOverlay
        }
        // DUT-529 — drive the snackbar's present/dismiss transition; `nil` under
        // Reduce Motion so it appears/disappears without motion (constitution §7).
        .animation(reduceMotion ? nil : .default, value: viewModel.snackbarMessage)
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

            // The Profile section MUST be first (above Use Metric Units) per the
            // locked CL-136 / DUT-36 Phase a decision, matching iOS Settings'
            // "Apple ID" placement. Renders the empty-state "Set up your profile"
            // row when none exists, else avatar + name + email; tap pushes
            // `ProfileEditView`. T-783 / DUT-89 — hidden on iPad (Profile lives
            // in the sidebar via SidebarProfileRow); the DUT-572 `hidesProfile`
            // signal is injected from RootView's real size class (a sheet reports
            // `.compact` on iPad). DUT-238 — account + sign-in (Sign in with
            // Apple, Sign Out, Delete) all live inside the Profile flow now; the
            // former standalone Settings ▸ Account section (US-46) is removed.
            ProfileSettingsSection(viewModel: viewModel, hidesProfile: hidesProfile)

            // MARK: T-750 / CL-147 — Measurements & Units group
            // (T-647 / CL-125 — every Section gets `.listRowBackground(DODColor.surfaceElevated)`.)

            // DUT-56 — the "Use Metric Units" toggle (US-32 AC-32.4) + the
            // "Recipe Step Temperatures" picker (DUT-47) grouped into one titled
            // section so the two unit-related controls sit together.
            Section {
                // DUT-517 — the "Use Metric Units" toggle drives a live consumer:
                // `IngredientMetricConverter` rewrites each scaled ingredient line
                // to metric (grams / millilitres) at display time in Recipe Detail
                // + the Cook Mode drawer. The former DUT-307 "Coming soon" gate is
                // removed now that the conversion path exists.
                Toggle(isOn: useMetricUnitsBinding) {
                    Text("Use Metric Units")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                }
                .accessibilityIdentifier("settings-toggle-metric")

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
                .tint(DODColor.burntOrange)
            } header: {
                sectionHeader("Measurements & Units")
            } footer: {
                Text(
                    "Use Metric Units converts ingredient measurements to metric (grams, milliliters). "
                        + "Recipe Step Temperatures converts temperatures shown in the steps; "
                        + "\"Recipe Default\" shows them as written."
                )
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
                // DUT-551 (CL-306) — brand-orange menu value + chevron (was the
                // default system blue).
                .tint(DODColor.burntOrange)
                .accessibilityIdentifier("settings-picker-appearance")
                LayoutSettingPicker()

                VoiceRows(viewModel: viewModel)

                CookModeControlsPicker()  // DUT-596
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
            // Data + Clear Cached Recipe Images + the DUT-679 Privacy Policy link
            // under one "Data & Privacy" header (iCloud alert + status refresh
            // stay on the host body). T-758 / CL-155 (DUT-64) — Clear Cache below
            // the telemetry toggle.
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

                // DUT-679 — App Store Guideline 5.1.1(i) in-app Privacy Policy
                // link (see `SettingsViewModel+Privacy.swift`).
                if let privacyPolicyURL = URL(string: SettingsViewModel.privacyPolicyURLString) {
                    Link(destination: privacyPolicyURL) {
                        Text("Privacy Policy")
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.accent)
                    }
                    .accessibilityIdentifier("settings-privacy-policy-link")
                    .accessibilityLabel("Privacy Policy, opens in browser")
                }
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
                // DUT-362: key the overlay by the message so a NEW message gives it
                // fresh identity and restarts the 4s auto-dismiss `.task` (otherwise
                // the first message's timer fires and clears the second one early).
                .id(message)
                .padding(.bottom, DODSpacing.md)
                // DUT-529: under Reduce Motion, drop the slide and crossfade in
                // with opacity only (constitution §7); otherwise slide up + fade.
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .bottom).combined(with: .opacity)
                )
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
