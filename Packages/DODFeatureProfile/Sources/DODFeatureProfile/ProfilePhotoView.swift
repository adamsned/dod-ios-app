import DODDesignSystem
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Small wrapper that shows the user's uploaded profile photo when one
/// exists on disk, otherwise falls back to ``InitialLetterAvatarView``.
///
/// **Phase b — wire-in to disk.** When ``UserProfile/photoFilename``
/// resolves a file inside the app's Documents directory (via
/// ``ProfilePhotoStoring/load(filename:)``) the view renders that
/// image inside a `Circle()`-clipped frame. When the filename is `nil`
/// OR the underlying file is missing (graceful degradation — the
/// Keychain may carry a stale filename if the user wiped the Documents
/// directory via Files.app, or a partial sync from a future cross-
/// device push) the view falls back to the initial-letter avatar.
///
/// The host passes a ``ProfilePhotoStoring`` so the same view works in
/// previews + tests with an injected fake. When the photo store is
/// `nil` (e.g. preview hosts that don't wire one) the view falls
/// through to the initial-letter avatar without attempting a load.
///
/// Load lifecycle: the image is loaded lazily in `.task` whenever the
/// `profile?.photoFilename` changes; the result is cached in
/// `@State private var loadedImage` so re-renders don't re-touch disk.
///
/// Spec trace: US-44 AC-44.3; CL-137.
public struct ProfilePhotoView: View {

    public let profile: UserProfile?
    public let diameter: CGFloat
    #if canImport(UIKit)
    /// Photo store from which to load `photoFilename`. `nil` in previews
    /// + tests that don't wire one — the view falls through to the
    /// initial-letter avatar in that case. UIKit-gated because
    /// ``ProfilePhotoStoring`` returns ``UIImage``.
    public let photoStore: (any ProfilePhotoStoring)?

    public init(
        profile: UserProfile?,
        diameter: CGFloat = 60,
        photoStore: (any ProfilePhotoStoring)? = nil
    ) {
        self.profile = profile
        self.diameter = diameter
        self.photoStore = photoStore
    }
    #else
    public init(profile: UserProfile?, diameter: CGFloat = 60) {
        self.profile = profile
        self.diameter = diameter
    }
    #endif

    public var body: some View {
        #if canImport(UIKit)
        contentWithLoader
        #else
        // macOS doesn't ship the photo flow — fall through to the
        // initial-letter avatar. `ProfilePhotoStore` itself is UIKit-
        // gated so there's no load to perform here.
        InitialLetterAvatarView(
            displayName: profile?.displayName ?? "",
            diameter: diameter
        )
        #endif
    }

    #if canImport(UIKit)
    @State private var loadedImage: UIImage?
    @State private var loadAttemptedFilename: String?

    @ViewBuilder
    private var contentWithLoader: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            } else {
                InitialLetterAvatarView(
                    displayName: profile?.displayName ?? "",
                    diameter: diameter
                )
            }
        }
        .task(id: profile?.photoFilename) {
            await loadPhotoIfNeeded()
        }
    }

    /// Loads the image from the photo store if the filename has changed
    /// since the last load attempt. Idempotent — re-entering with the
    /// same filename is a no-op so a parent re-render doesn't re-touch
    /// disk.
    @MainActor
    private func loadPhotoIfNeeded() async {
        let filename = profile?.photoFilename
        // Filename cleared — drop the cached image too so the avatar
        // re-renders.
        guard let filename else {
            loadedImage = nil
            loadAttemptedFilename = nil
            return
        }
        // Same filename, already loaded — no-op.
        if loadAttemptedFilename == filename, loadedImage != nil { return }
        // Filename changed to a different photo — drop the stale cached image so
        // the placeholder shows during the load, not the previous profile's photo.
        if loadAttemptedFilename != filename { loadedImage = nil }
        loadAttemptedFilename = filename
        guard let photoStore else {
            // No store wired (preview / test host) — graceful fallback.
            loadedImage = nil
            return
        }
        let image = await photoStore.load(filename: filename)
        // The view may have been re-tasked with a different filename
        // by the time the await returns — assign only if the filename
        // we loaded for still matches the current profile's filename.
        if profile?.photoFilename == filename {
            loadedImage = image
        }
    }
    #endif
}

#Preview("ProfilePhotoView — guest") {
    ProfilePhotoView(profile: nil)
        .padding()
        .background(DODColor.surface)
}

#Preview("ProfilePhotoView — populated (no photo)") {
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
