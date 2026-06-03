import DODFeatureFeed
import DODFeatureProfile
import SwiftUI

/// Shared trailing-edge Settings gear, applied at the composition root so
/// EVERY top-level tab (Recipes/Feed, Categories, Search, Saved) carries the
/// same entry point in the same spot (DUT-26).
///
/// Presentation is a MODAL SHEET, not a toolbar `NavigationLink` (DUT-35).
/// On iPad the app's shell is a `NavigationSplitView`. Hanging a
/// `NavigationLink` off a `.toolbar` on the detail column's `NavigationStack`
/// root and then pushing a recipe/article detail — which declares its OWN
/// `.toolbar` — forces SwiftUI to reconcile two toolbar-hosted navigation
/// destinations into the split view's single shared nav bar, which crashes on
/// iPad (opening any recipe or article). iPhone's `TabView` gives each tab an
/// independent nav bar, so the original push form shipped fine there and only
/// iPad blew up. Presenting Settings from a plain `Button` as a `.sheet`
/// removes the toolbar `NavigationLink` entirely, so there is nothing left to
/// collide with the pushed detail's toolbar. Behavior is identical on iPhone
/// (`TabView`) and iPad (`NavigationSplitView`).
///
/// The gear stays at the absolute trailing edge on every screen — same glyph,
/// same accessibility label "Settings", same per-screen identifier stem —
/// applied AFTER any tab-specific trailing items so ordering is stable.
struct SettingsToolbarModifier: ViewModifier {

    /// Per-screen accessibility identifier stem so each tab's gear has a
    /// stable, unique handle (e.g. `feed-toolbar-settings`). The user-facing
    /// accessibility *label* stays "Settings" on every tab so VoiceOver and
    /// the L3 smoke test's `app.buttons["Settings"]` query resolve identically.
    let identifierStem: String
    /// The Settings dependency surface, forwarded into `SettingsView`'s
    /// `SettingsViewModel` exactly as `FeedView` did pre-DUT-26.
    let settingsDependencies: (any SettingsDependencies)?
    /// US-36 / AC-36.4 — Clear Cached Recipe Images closure routed into the
    /// Settings "Clear Cache" row. `nil` surfaces the zero-bytes copy.
    let onClearImageCache: (() async throws -> Int)?
    /// US-42 / AC-42.1 — notification-authorization seam. `nil` reports
    /// "not granted" when the user flips the toggle ON.
    let onRequestNotificationAuthorization: (@MainActor () async -> Bool)?
    /// US-40 / AC-40.12 + AC-40.13 — Cook Mode Voice catalog + preview seam.
    let voicePreviewer: (any VoicePreviewing)?
    /// US-44 (T-739) — Keychain-backed profile store consumed by the
    /// Settings → Profile section and its push-destination
    /// `ProfileEditView`. Forwarded through to the `SettingsViewModel`
    /// init so the row reflects the persisted profile on every sheet
    /// open. `nil` in surfaces (previews, snapshot hosts) that haven't
    /// wired a store; the section renders the empty "Set up your
    /// profile" state and the edit-view fallback surfaces a placeholder.
    let profileStore: (any ProfileStoring)?
    #if canImport(UIKit)
    /// US-44 Phase b (T-740) — on-disk photo store routed alongside
    /// `profileStore` so the Settings Profile section's avatar +
    /// the edit view's picker flow both surface the persisted photo.
    /// UIKit-gated because the underlying store returns `UIImage`.
    let profilePhotoStore: (any ProfilePhotoStoring)?
    #endif

    /// Drives the Settings sheet. Each tab's modifier instance owns its own
    /// presentation state, so the gear opens that tab's Settings sheet.
    @State private var isSettingsPresented = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    settingsToolbarButton
                }
                #else
                ToolbarItem(placement: .automatic) {
                    settingsToolbarButton
                }
                #endif
            }
            .sheet(isPresented: $isSettingsPresented) {
                settingsSheet
            }
    }

    /// The gear-icon button. Opens Settings as a modal sheet (DUT-35) rather
    /// than pushing it through a toolbar `NavigationLink`.
    private var settingsToolbarButton: some View {
        Button {
            isSettingsPresented = true
        } label: {
            Image(systemName: "gearshape")
                .accessibilityLabel("Settings")
        }
        .accessibilityIdentifier("\(identifierStem)-toolbar-settings")
    }

    /// Settings inside its own `NavigationStack` (it expects a nav bar for its
    /// title) with a Done button to dismiss the sheet. The `SettingsViewModel`
    /// is built lazily here, matching the old `NavigationLink` destination.
    private var settingsSheet: some View {
        NavigationStack {
            SettingsView(
                viewModel: settingsViewModel,
                onClearImageCache: onClearImageCache
            )
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    settingsDoneButton
                }
                #else
                ToolbarItem(placement: .automatic) {
                    settingsDoneButton
                }
                #endif
            }
        }
    }

    /// Builds the `SettingsViewModel` for the sheet, picking the iOS-
    /// only convenience init that threads the Phase b
    /// `ProfilePhotoStoring` collaborator when UIKit is available, and
    /// falling back to the plain init on other platforms. Extracted into
    /// a computed property so the `#if canImport(UIKit)` plumbing stays
    /// inside a single value body rather than straddling a function
    /// call's argument list and trailing closure (which Swift does not
    /// allow). T-740 / CL-137.
    private var settingsViewModel: SettingsViewModel {
        #if canImport(UIKit)
        SettingsViewModel(
            dependencies: settingsDependencies,
            voicePreviewer: voicePreviewer,
            profileStore: profileStore,
            profilePhotoStore: profilePhotoStore,
            requestNotificationAuthorization: onRequestNotificationAuthorization ?? { false }
        )
        #else
        SettingsViewModel(
            dependencies: settingsDependencies,
            voicePreviewer: voicePreviewer,
            profileStore: profileStore,
            requestNotificationAuthorization: onRequestNotificationAuthorization ?? { false }
        )
        #endif
    }

    private var settingsDoneButton: some View {
        Button("Done") {
            isSettingsPresented = false
        }
        .accessibilityIdentifier("\(identifierStem)-settings-done")
    }
}
