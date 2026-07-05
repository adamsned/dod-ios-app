import SwiftUI

#if canImport(UIKit)
import UIKit

// Extracted from `ProfileEditView.swift` so that file stays under the SwiftLint
// 400-line file_length cap (DUT-565 added the `extraTeardown` teardown seam).
extension ProfileEditView {

    /// Identifiable wrapper around the picked image so we can drive a
    /// `.sheet(item:)` presentation by the image itself (rather than a
    /// `Bool` + a separate optional state variable).
    struct CropCandidate: Identifiable {
        let id = UUID()
        let image: UIImage
    }
}
#endif
