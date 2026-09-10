import Foundation

/// Identifiable box driving the recipe share `.sheet(item:)`: the generated PDF
/// file plus the recipe's canonical web link. Foundation-only (no UIKit) so the
/// view state compiles on the macOS `swift test` slice; the sheet is iOS-only.
struct SharePDFItem: Identifiable {
    let id = UUID()
    /// The print-ready recipe PDF (a local file URL).
    let pdfURL: URL
    /// The recipe's canonical web URL, shared alongside the PDF so link targets
    /// (Messages, Mail) get a rich preview (DUT-1324).
    let linkURL: URL
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

/// Supplies the recipe's canonical URL to share targets, but WITHHOLDS it from
/// Print so Print falls to the PDF (the custom sheet) rather than the web page.
/// This lets the share sheet carry both a printable PDF and a link-previewable
/// URL without the two printable items fighting over Print (DUT-1324).
final class LinkActivityItemSource: NSObject, UIActivityItemSource {

    private let url: URL

    init(_ url: URL) {
        self.url = url
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(
        _ controller: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        // nil for Print → the URL isn't offered to Print, so the PDF prints.
        activityType == .print ? nil : url
    }
}
#endif
