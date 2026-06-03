import DODDesignSystem
import DODFeatureProfile
import SwiftUI

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
