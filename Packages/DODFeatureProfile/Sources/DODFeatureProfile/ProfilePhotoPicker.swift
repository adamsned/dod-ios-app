#if canImport(UIKit)
import PhotosUI
import SwiftUI

/// Thin SwiftUI wrapper around ``PhotosPicker`` so the edit view's row
/// can present the picker with a custom label without inlining the
/// `matching:` / `photoLibrary:` configuration at every call site.
///
/// **Privacy posture.** ``PhotosPicker`` uses Apple's privacy-preserving
/// picker — selection passes through Photos.app without granting the
/// app full library access, so **no `NSPhotoLibraryUsageDescription`
/// Info.plist entry is required + no permission alert is shown to the
/// user**. Locked per CL-137 decision (1) — the legacy
/// `UIImagePickerController(allowsEditing: true)` was considered and
/// rejected on these privacy grounds even though it ships a built-in
/// square cropper for free.
///
/// **Selection contract.** Single image, `.images` filter, shared photo
/// library. The host listens to `selection`'s `.onChange` to load the
/// transferable `Data`, hands the resulting `UIImage` to
/// ``ProfilePhotoCropView``, and resets `selection` to `nil` when the
/// flow completes.
///
/// Spec trace: US-44 AC-44.3; CL-137.
public struct ProfilePhotoPicker<Label: View>: View {

    @Binding var selection: PhotosPickerItem?
    let label: () -> Label

    public init(
        selection: Binding<PhotosPickerItem?>,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self._selection = selection
        self.label = label
    }

    public var body: some View {
        PhotosPicker(
            selection: $selection,
            matching: .images,
            photoLibrary: .shared(),
            label: label
        )
        .accessibilityIdentifier("profile-photo-picker")
    }
}
#endif
