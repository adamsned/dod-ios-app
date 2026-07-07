import DODDesignSystem
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// The Profile row at the top of Settings. Two states:
///
/// 1. **Empty (no profile yet).** Renders a single-line "Set up your
///    profile" prompt + trailing chevron. Tap pushes
///    ``ProfileEditView`` in its new-profile state.
/// 2. **Populated.** Renders a 60pt avatar leading, display name + email
///    stacked in the center, trailing chevron. Tap pushes
///    ``ProfileEditView`` in its edit state.
///
/// The host (`SettingsView`) wraps this row in a `Section` and applies
/// `.listRowBackground(DODColor.surfaceElevated)` to match the T-647 /
/// CL-125 brand-brown row treatment shared with every other Settings
/// section. The chevron is intentionally drawn as a `NavigationLink`
/// label so iOS's default disclosure chevron + the row's tap region are
/// both handled by SwiftUI's stock plumbing — no custom button-style
/// gymnastics.
///
/// Spec trace: US-44 AC-44.1; CL-136.
public struct ProfileSection<Destination: View>: View {

    public let profile: UserProfile?
    public let destination: () -> Destination
    #if canImport(UIKit)
    /// Phase b (T-740) — optional photo store routed into the populated
    /// row's ``ProfilePhotoView`` so Settings surfaces the uploaded
    /// photo when one exists (otherwise falls back to the initial-
    /// letter avatar). `nil` for previews + snapshot hosts. UIKit-gated.
    public let photoStore: (any ProfilePhotoStoring)?

    public init(
        profile: UserProfile?,
        photoStore: (any ProfilePhotoStoring)? = nil,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.profile = profile
        self.photoStore = photoStore
        self.destination = destination
    }
    #else
    public init(
        profile: UserProfile?,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        self.profile = profile
        self.destination = destination
    }
    #endif

    public var body: some View {
        NavigationLink {
            destination()
        } label: {
            if let profile {
                populatedRow(for: profile)
            } else {
                emptyRow
            }
        }
        .accessibilityIdentifier("settings-link-profile")
    }

    // MARK: - Row variants

    @ViewBuilder
    private var emptyRow: some View {
        Text("Set Up Your Profile")
            .dodFont(DODType.body)
            .foregroundStyle(DODColor.label)
    }

    @ViewBuilder
    private func populatedRow(for profile: UserProfile) -> some View {
        HStack(spacing: DODSpacing.md) {
            #if canImport(UIKit)
            ProfilePhotoView(profile: profile, diameter: 60, photoStore: photoStore)
            #else
            ProfilePhotoView(profile: profile, diameter: 60)
            #endif
            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                Text(profile.displayName)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                    .lineLimit(1)
                    // DUT-693 PR4: shrink before truncating (mirrors the email line
                    // below) so the name stays readable at large Dynamic Type sizes.
                    .minimumScaleFactor(0.7)
                Text(profile.email)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .lineLimit(1)
                    // DUT-359: shrink before truncating so the email stays readable
                    // at large Dynamic Type sizes (the avatar + row width are fixed).
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DODSpacing.xxs)
    }
}

#Preview("ProfileSection — empty") {
    NavigationStack {
        List {
            Section {
                ProfileSection(profile: nil) {
                    Text("Edit view goes here")
                }
            }
            .listRowBackground(DODColor.surfaceElevated)
        }
        .scrollContentBackground(.hidden)
        .background(DODColor.surface)
    }
}

#Preview("ProfileSection — populated") {
    NavigationStack {
        List {
            Section {
                ProfileSection(
                    profile: UserProfile(
                        id: UUID(),
                        displayName: "Spencer Adams",
                        email: "spencer@example.com"
                    )
                ) {
                    Text("Edit view goes here")
                }
            }
            .listRowBackground(DODColor.surfaceElevated)
        }
        .scrollContentBackground(.hidden)
        .background(DODColor.surface)
    }
}
