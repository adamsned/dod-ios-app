import DODDesignSystem
import DODFeatureProfile
import SwiftUI

#if canImport(UIKit)
import UIKit  // T-783 / DUT-89 — UIDevice.userInterfaceIdiom (see ProfileSettingsSection)
#endif

// US-44 Phase b (T-740) — Profile row at the top of Settings.
//
// Extracted from `SettingsView.swift` so that file stays under the
// SwiftLint 400-line file_length cap. The split also lets the
// `#if canImport(UIKit)` photo-store plumbing live inside a single
// view body rather than straddling a function call's `(...)` argument
// list and `{...}` trailing closure — Swift does not allow `#if` to
// span that boundary, so the section is built as a dedicated `View`
// that picks the right call shape at compile time.
//
// The sub-view takes the view-model as a constructor parameter rather
// than reaching for the host's `@State` (which is `private` and not
// accessible from a sibling file).
//
// Spec trace: US-44 AC-44.1, AC-44.3; CL-136, CL-137.

/// Renders the Profile row + push-destination at the top of the
/// Settings list (above Use Metric Units per CL-136). Two states:
/// empty ("Set up your profile") + populated (avatar + display name +
/// email). Tap pushes ``ProfileEditView``.
struct ProfileSettingsRow: View {

    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        #if canImport(UIKit)
        ProfileSection(
            profile: viewModel.profile,
            photoStore: viewModel.profilePhotoStore
        ) {
            if let profileStore = viewModel.profileStore {
                ProfileEditView(
                    store: profileStore,
                    existingProfile: viewModel.profile,
                    onProfileChanged: { [weak viewModel] in
                        await viewModel?.refreshProfile()
                    },
                    photoStore: viewModel.profilePhotoStore
                )
            } else {
                // Previews + snapshot hosts without a wired store:
                // surface a placeholder rather than crash. Production
                // always has a store.
                Text("Profile editing requires a store.")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
            }
        }
        #else
        ProfileSection(profile: viewModel.profile) {
            if let profileStore = viewModel.profileStore {
                ProfileEditView(
                    store: profileStore,
                    existingProfile: viewModel.profile,
                    onProfileChanged: { [weak viewModel] in
                        await viewModel?.refreshProfile()
                    }
                )
            } else {
                Text("Profile editing requires a store.")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
            }
        }
        #endif
    }
}

/// T-783 / DUT-89 — wraps the Settings Profile section so it can be hidden on
/// iPad, where the Profile lives in the sidebar (``SidebarProfileRow``). The
/// `horizontalSizeClass` — the SAME signal `RootView` uses to choose the shell —
/// is the gate (DUT-299): hide only in a REGULAR-width window (iPadSplit, where
/// the sidebar's `SidebarProfileRow` is present). A COMPACT window (iPhone OR an
/// iPad multitasking / Slide Over pane) has no sidebar, so the Settings Profile
/// row is the only entry point there and must show.
struct ProfileSettingsSection: View {

    @Bindable var viewModel: SettingsViewModel
    #if canImport(UIKit)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        if !hidesProfileSection {
            Section {
                ProfileSettingsRow(viewModel: viewModel)
            }
            .listRowBackground(DODColor.surfaceElevated)
        }
    }

    private var hidesProfileSection: Bool {
        // DUT-299: hide only when the sidebar (SidebarProfileRow) is actually
        // present — a regular-width window. In compact width (iPhone OR an iPad
        // multitasking / Slide Over pane) RootView shows phoneTabs with no
        // sidebar, so this Profile row is the ONLY way to reach the editor.
        #if canImport(UIKit)
        horizontalSizeClass == .regular
        #else
        false
        #endif
    }
}
