import SwiftUI

// UIKit-gated: `photoStore` + the in-flight photo state live behind
// `#if canImport(UIKit)` (the store returns `UIImage`).
#if canImport(UIKit)
extension ProfileEditView {

    /// DUT-353: on abandon ("Leave Without Saving"), delete this-session photo
    /// files that were written but never persisted, so leaving an edit doesn't
    /// orphan them in Documents — the deferred clear-on-save markers only run in
    /// `handleSave`, which the abandon path skips. UIKit-free (just filenames +
    /// the store), so it lives outside the `+Photo` UIKit-gated extension.
    func discardUnsavedPhotoFiles() {
        guard let photoStore else { return }
        let saved = existingProfile
        if let name = inFlightPhotoFilename, name != saved?.photoFilename {
            Task { try? await photoStore.clear(filename: name) }
        }
        if let name = inFlightPhotoOriginalFilename, name != saved?.photoOriginalFilename {
            Task { try? await photoStore.clearOriginal(filename: name) }
        }
    }
}
#endif
