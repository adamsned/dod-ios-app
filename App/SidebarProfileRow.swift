import DODDesignSystem
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

    @State private var profile: UserProfile?
    @State private var showingEditor = false

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
                        photoStore: profilePhotoStore
                    )
                }
            }
        }
    }

    private func reload() async {
        profile = await profileStore?.load()
    }
}
