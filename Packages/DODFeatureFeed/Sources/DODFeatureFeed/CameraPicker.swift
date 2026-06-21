#if canImport(UIKit)
import SwiftUI
import UIKit

/// A minimal camera-capture sheet (DUT-184) — wraps `UIImagePickerController`
/// with the `.camera` source so the cook can snap their finished dish right in
/// the "Your First Cookout" celebrate stage and share it.
///
/// iOS-only: the whole file is `canImport(UIKit)`-guarded so the macOS test
/// slice (which has no `UIImagePickerController`) still builds. Callers gate the
/// entry point on `UIImagePickerController.isSourceTypeAvailable(.camera)` so the
/// "Take a photo" affordance is hidden where there's no camera (e.g. Simulator).
struct CameraPicker: UIViewControllerRepresentable {

    /// Called with the captured image, or `nil` if the cook cancelled. Either
    /// way the presenter should dismiss (set its `isPresented` binding false).
    let onComplete: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onComplete: (UIImage?) -> Void

        init(onComplete: @escaping (UIImage?) -> Void) {
            self.onComplete = onComplete
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onComplete(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onComplete(nil)
        }
    }
}
#endif
