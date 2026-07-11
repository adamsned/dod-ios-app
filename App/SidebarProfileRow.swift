import DODDesignSystem
import DODFeatureFeed
import DODFeatureProfile
import DODSupport
import SwiftUI

/// T-783 / DUT-89 — Profile entry pinned at the top of the iPad sidebar.
///
/// On iPad the Settings → Profile section is hidden (the profile "moves" here);
/// the sidebar is iPad-only (`RootView.iPadSplit`), so this never touches the
/// iPhone Settings flow. Shows the avatar + title/subtitle resolved by
/// ``SidebarProfileDisplay`` — a named profile, a "Signed In" state for a
/// signed-in user with no name yet (DUT-935), or a "Set up your profile"
/// guest placeholder — and opens ``ProfileEditView`` as a sheet on tap,
/// reloading the row when the editor saves.
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
    /// DUT-935 — read alongside `profile` so the row can tell "signed in, no
    /// name yet" (Apple only returns the name on the very first
    /// authorization) apart from a true guest. Defaults to the real Keychain
    /// store so previews/hosts that don't override it keep working.
    var sessionStore: (any AppleAuthSessionStoring) = KeychainAppleAuthSessionStore()

    @State private var profile: UserProfile?
    @State private var session: AppleAuthSession?
    @State private var showingEditor = false
    @State private var showingJournal = false

    var body: some View {
        Button {
            showingEditor = true
        } label: {
            HStack(spacing: DODSpacing.sm) {
                ProfilePhotoView(profile: profile, diameter: 40, photoStore: profilePhotoStore)
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayCopy.title)
                        .dodFont(DODType.heading)
                        .foregroundStyle(DODColor.label)
                        .lineLimit(1)
                        // DUT-695 — shrink rather than clip at large Dynamic Type.
                        .minimumScaleFactor(0.8)
                    Text(displayCopy.subtitle)
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                        .lineLimit(1)
                        // DUT-695 — shrink rather than clip at large Dynamic Type.
                        .minimumScaleFactor(0.8)
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

    /// DUT-935 — the row's title/subtitle, resolved from the loaded profile
    /// + auth session by the pure ``SidebarProfileDisplay`` resolver.
    private var displayCopy: (title: String, subtitle: String) {
        SidebarProfileDisplay.resolve(profile: profile, session: session)
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
                // DUT-694 (PR-D) — the journal closures now return success; a
                // deallocated view-model reports success so a torn-down sheet
                // never raises a false failure alert.
                update: { [weak settingsViewModel] entry in
                    await settingsViewModel?.updateProfileJournalEntry(entry) ?? true
                },
                delete: { [weak settingsViewModel] entry in
                    await settingsViewModel?.deleteProfileJournalEntry(entry) ?? true
                }
            )
        }
    }

    private func reload() async {
        profile = await profileStore?.load()
        session = try? sessionStore.load()
    }
}
