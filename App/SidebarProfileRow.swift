import DODDesignSystem
import DODFeatureFeed
import DODFeatureProfile
import SwiftUI

/// T-783 / DUT-89 — Profile entry pinned at the top of the iPad sidebar.
///
/// On iPad the Settings → Profile section is hidden (the profile "moves" here);
/// the sidebar is iPad-only (`RootView.iPadSplit`), so this never touches the
/// iPhone Settings flow. Shows the avatar + display name — or a "Set up your
/// profile" placeholder when none exists yet — and opens ``ProfileEditView`` as
/// a sheet on tap, reloading the row when the editor saves.
struct SidebarProfileRow: View {

    let profileStore: (any ProfileStoring)?
    let profilePhotoStore: (any ProfilePhotoStoring)?
    /// DUT-565 — extra local-state clears (recent searches + comment moderation)
    /// threaded into the editor's account teardown. Injected by `RootView` (the
    /// composition root that owns those stores). `nil` in previews.
    var accountTeardownExtras: (@MainActor (Bool) async -> Void)?
    /// DUT-607 — the same `SettingsViewModel` the iPhone `ProfileSettingsRow`
    /// reads to build the profile-stats hooks. Injected by `RootView` so the iPad
    /// sidebar's `ProfileEditView` shows the Cook Rank / counts / "View Cooking
    /// Journal" section the iPhone Settings profile does (it was previously built
    /// WITHOUT `statsHooks`, so the whole stats section silently vanished on iPad).
    /// `nil` in previews / unwired hosts, which just hides the section.
    var settingsViewModel: SettingsViewModel?

    @State private var profile: UserProfile?
    @State private var showingEditor = false
    @State private var showingJournal = false

    var body: some View {
        Button {
            showingEditor = true
        } label: {
            HStack(spacing: DODSpacing.sm) {
                ProfilePhotoView(profile: profile, diameter: 40, photoStore: profilePhotoStore)
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile?.displayName ?? "Set Up Your Profile")
                        .dodFont(DODType.heading)
                        .foregroundStyle(DODColor.label)
                        .lineLimit(1)
                    Text(profile == nil ? "Add Your Name and Photo" : "View profile")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sidebar-profile-row")
        .task { await reload() }
        .sheet(isPresented: $showingEditor) {
            if let profileStore {
                NavigationStack {
                    ProfileEditView(
                        store: profileStore,
                        existingProfile: profile,
                        onProfileChanged: { await reload() },
                        photoStore: profilePhotoStore,
                        // DUT-607 — pass the stats hooks like the iPhone row does.
                        statsHooks: profileStatsHooks,
                        extraTeardown: accountTeardownExtras
                    )
                }
            }
        }
        .sheet(isPresented: $showingJournal) { cookJournalSheet }
    }

    /// DUT-607 — composition hooks for the profile stats section, built from the
    /// injected `SettingsViewModel` exactly like `ProfileSettingsRow`. Nil (section
    /// hidden) until a real dependency is wired (`profileStatsAvailable`).
    private var profileStatsHooks: ProfileStatsHooks? {
        guard let settingsViewModel, settingsViewModel.profileStatsAvailable else { return nil }
        return ProfileStatsHooks(
            load: { [weak settingsViewModel] in await settingsViewModel?.loadProfileStats() ?? .empty },
            viewCookingJournal: { showingJournal = true }
        )
    }

    /// DUT-607 — the Cooking Journal sheet (read + in-place edit), reusing the
    /// same `CookJournalView` the iPhone profile stats section presents.
    @ViewBuilder
    private var cookJournalSheet: some View {
        if let settingsViewModel {
            CookJournalView(
                load: { [weak settingsViewModel] in await settingsViewModel?.profileJournalEntries() ?? [] },
                update: { [weak settingsViewModel] entry in
                    await settingsViewModel?.updateProfileJournalEntry(entry)
                },
                delete: { [weak settingsViewModel] entry in
                    await settingsViewModel?.deleteProfileJournalEntry(entry)
                }
            )
        }
    }

    private func reload() async {
        profile = await profileStore?.load()
    }
}
