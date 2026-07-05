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
    /// DUT-417 — drives the "View Cooking Journal" sheet presented from the
    /// profile stats section.
    @State private var showingJournal = false

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
                    photoStore: viewModel.profilePhotoStore,
                    statsHooks: profileStatsHooks,
                    extraTeardown: viewModel.accountTeardownExtras
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
        .sheet(isPresented: $showingJournal) { cookJournalSheet }
        #else
        ProfileSection(profile: viewModel.profile) {
            if let profileStore = viewModel.profileStore {
                ProfileEditView(
                    store: profileStore,
                    existingProfile: viewModel.profile,
                    onProfileChanged: { [weak viewModel] in
                        await viewModel?.refreshProfile()
                    },
                    statsHooks: profileStatsHooks,
                    extraTeardown: viewModel.accountTeardownExtras
                )
            } else {
                Text("Profile editing requires a store.")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
            }
        }
        .sheet(isPresented: $showingJournal) { cookJournalSheet }
        #endif
    }

    /// DUT-417 — composition hooks for the profile stats section. Nil (section
    /// hidden) until a real dependency is wired (`profileStatsAvailable`).
    private var profileStatsHooks: ProfileStatsHooks? {
        guard viewModel.profileStatsAvailable else { return nil }
        return ProfileStatsHooks(
            load: { [weak viewModel] in await viewModel?.loadProfileStats() ?? .empty },
            viewCookingJournal: { showingJournal = true }
        )
    }

    /// The Cooking Journal sheet (read + in-place edit), reusing the same
    /// `CookJournalView` the Feed presents.
    private var cookJournalSheet: some View {
        CookJournalView(
            load: { [weak viewModel] in await viewModel?.profileJournalEntries() ?? [] },
            update: { [weak viewModel] entry in await viewModel?.updateProfileJournalEntry(entry) },
            delete: { [weak viewModel] entry in await viewModel?.deleteProfileJournalEntry(entry) }  // DUT-514
        )
    }
}

/// T-783 / DUT-89 — wraps the Settings Profile section so it can be hidden on
/// iPad, where the Profile lives in the sidebar (``SidebarProfileRow``).
///
/// DUT-572 — the hide decision is now INJECTED (`hidesProfile`) rather than read
/// from this view's own `horizontalSizeClass`. SettingsView is presented as a
/// `.sheet`, and a sheet on iPad reports `.compact` horizontalSizeClass, so an
/// in-sheet size-class read could never see the regular width and the Profile row
/// never hid on iPad. `RootView` (which reads the TRUE device size class) passes
/// `hidesProfile: horizontalSizeClass == .regular`, so the row hides exactly on
/// iPad (where `SidebarProfileRow` is present) and shows on iPhone / a compact
/// iPad multitasking pane (the only entry point there).
struct ProfileSettingsSection: View {

    @Bindable var viewModel: SettingsViewModel
    /// Injected from `RootView`'s real device size class (see type doc). When
    /// true the section renders nothing (Profile lives in the sidebar on iPad).
    let hidesProfile: Bool

    var body: some View {
        if !hidesProfile {
            Section {
                ProfileSettingsRow(viewModel: viewModel)
            }
            .listRowBackground(DODColor.surfaceElevated)
        }
    }
}
