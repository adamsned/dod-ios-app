import Foundation

/// Identifiable box so a freshly generated PDF file URL can drive a
/// `.sheet(item:)` presentation. Foundation-only (no UIKit) so the view state
/// compiles on the macOS `swift test` slice; the actual sheet is iOS-only.
struct SharePDFItem: Identifiable {
    let id = UUID()
    let url: URL
}

#if os(iOS) && canImport(UIKit)
import SwiftUI
import UIKit

/// Thin SwiftUI wrapper over `UIActivityViewController` — the full iOS share
/// sheet (Print, AirDrop, Messages, Mail, contacts, share extensions). Used by
/// Recipe Detail to present the generated recipe PDF on demand (DUT-1324); a
/// `ShareLink` can't be used because the PDF is built at tap time, not upfront.
struct ShareSheet: UIViewControllerRepresentable {

    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
