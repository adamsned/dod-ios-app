import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// DUT-976 — renders a recap card to a PNG file for ShareLink.
@MainActor
enum CookoutRecapRenderer {

    static func fileName(for day: Date) -> String {
        "cookout-recap-\(Int(day.timeIntervalSince1970)).png"
    }

    /// PNG bytes for `card` at 3x, or nil if rendering fails (always nil off UIKit).
    static func pngData<Content: View>(_ card: Content) -> Data? {
        #if canImport(UIKit)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage?.pngData()
        #else
        return nil
        #endif
    }
}
