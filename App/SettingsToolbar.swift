import DODFeatureFeed
import SwiftUI

/// Shared trailing-edge Settings gear, applied at the composition root so
/// EVERY top-level tab (Recipes/Feed, Categories, Search, Saved) carries the
/// same entry point in the same spot (DUT-26).
///
/// Before DUT-26 the gear lived only inside `FeedView` (US-32 AC-32.1). The
/// other three tab roots had no Settings affordance, so reaching Settings
/// from Categories / Search / Saved meant first hopping to the Recipes tab.
/// This modifier hoists the single canonical gear up to `TabStack`, where the
/// composition root already holds the full Settings dependency surface, and
/// hangs it off each tab's `NavigationStack`. One definition, four tabs — no
/// per-package copy of the wiring and no extra dependency edges (Categories /
/// Search / Saved never gain a `DODFeatureFeed` import).
///
/// The gear is a `NavigationLink` (push, not sheet) so it inherits the
/// standard back button on the pushed Settings screen and rides the per-tab
/// `NavigationStack` `TabStack` already hosts — identical to the presentation
/// `FeedView.settingsToolbarLink` used pre-DUT-26, so the Settings navigation
/// is unchanged.
///
/// Placement is `.topBarTrailing` on iOS (matching `FeedView` / `SearchView`)
/// with the same `.automatic` fallback for the macOS `swift test` slice where
/// `.topBarTrailing` is unavailable. Declared via a single `.toolbar`
/// modifier applied AFTER any tab-specific trailing items (Feed/Search layout
/// toggle, Saved "Make Shopping List"), so SwiftUI orders the gear at the
/// absolute trailing edge on every screen — same icon, same position,
/// same behavior. Works on both iPhone (`TabView`) and iPad
/// (`NavigationSplitView`) because both shells route through `TabStack`.
struct SettingsToolbarModifier: ViewModifier {

    /// Per-screen accessibility identifier stem so each tab's gear has a
    /// stable, unique handle (e.g. `feed-toolbar-settings`,
    /// `search-toolbar-settings`). The user-facing accessibility *label*
    /// stays "Settings" on every tab so VoiceOver and the L3 smoke test's
    /// `app.buttons["Settings"]` query resolve identically across screens.
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

    func body(content: Content) -> some View {
        content.toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                settingsToolbarLink
            }
            #else
            ToolbarItem(placement: .automatic) {
                settingsToolbarLink
            }
            #endif
        }
    }

    /// The gear-icon `NavigationLink`. Mirrors the pre-DUT-26
    /// `FeedView.settingsToolbarLink` byte-for-byte (same `SettingsView`
    /// construction, same `gearshape` glyph, same "Settings" accessibility
    /// label) so the Settings presentation + navigation are reused, not
    /// re-implemented.
    private var settingsToolbarLink: some View {
        NavigationLink {
            SettingsView(
                viewModel: SettingsViewModel(
                    dependencies: settingsDependencies,
                    voicePreviewer: voicePreviewer,
                    requestNotificationAuthorization: onRequestNotificationAuthorization ?? { false }
                ),
                onClearImageCache: onClearImageCache
            )
        } label: {
            Image(systemName: "gearshape")
                .accessibilityLabel("Settings")
        }
        .accessibilityIdentifier("\(identifierStem)-toolbar-settings")
    }
}
