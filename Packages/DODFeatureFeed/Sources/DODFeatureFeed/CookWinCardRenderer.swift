import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Foundation-only Identifiable box driving the card share `.sheet(item:)`.
struct CookWinShareItem: Identifiable {
    let id = UUID()
    let pngData: Data
    let caption: String
}

/// DUT-966 — rasterises a `CookWinCardView` to PNG bytes.
enum CookWinCardRenderer {
    @MainActor
    static func pngData(content: CookWinCardContent, photo: Image?, scale: CGFloat = 3) -> Data? {
        let renderer = ImageRenderer(content: CookWinCardView(content: content, photo: photo))
        renderer.scale = scale
        guard let cgImage = renderer.cgImage else { return nil }
        let data = NSMutableData()
        guard
            let dest = CGImageDestinationCreateWithData(
                data,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else { return nil }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
