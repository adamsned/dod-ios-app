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

    /// Writes the PNG to the temp dir and returns its URL, or nil on any failure.
    static func writeFile<Content: View>(_ card: Content, day: Date) -> URL? {
        guard let data = pngData(card) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(for: day))
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
