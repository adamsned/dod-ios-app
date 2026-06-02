import DODDesignSystem
import SwiftUI

/// Small wrapper that shows the user's uploaded profile photo when one
/// exists on disk, otherwise falls back to ``InitialLetterAvatarView``.
///
/// **Phase a stub.** When ``UserProfile/photoFilename`` is `nil` (the
/// only state Phase a ships), this view always renders the initial-letter
/// fallback. When Phase b lands the photo picker + crop flow it sets
/// `photoFilename` to the on-disk filename inside the app's Documents
/// directory; this view then loads the image and renders it inside the
/// same circular frame. The loader is deliberately not implemented in
/// Phase a — `photoFilename` populated would simply fall through to the
/// initial-letter today.
///
/// Callers pass the full ``UserProfile`` rather than just the filename
/// so the fallback path has the display name on hand without a
/// secondary lookup.
///
/// Spec trace: US-44 AC-44.3, AC-44.5; CL-136.
public struct ProfilePhotoView: View {

    public let profile: UserProfile?
    public let diameter: CGFloat

    public init(profile: UserProfile?, diameter: CGFloat = 60) {
        self.profile = profile
        self.diameter = diameter
    }

    public var body: some View {
        // Phase a: always fall through to the initial-letter avatar.
        // Phase b will swap in a UIImage(contentsOfFile:) load from the
        // Documents directory when `profile?.photoFilename != nil`.
        InitialLetterAvatarView(
            displayName: profile?.displayName ?? "",
            diameter: diameter
        )
    }
}

#Preview("ProfilePhotoView — populated") {
    ProfilePhotoView(
        profile: UserProfile(
            id: UUID(),
            displayName: "Spencer Adams",
            email: "spencer@example.com"
        )
    )
    .padding()
    .background(DODColor.surface)
}

#Preview("ProfilePhotoView — guest") {
    ProfilePhotoView(profile: nil)
        .padding()
        .background(DODColor.surface)
}
