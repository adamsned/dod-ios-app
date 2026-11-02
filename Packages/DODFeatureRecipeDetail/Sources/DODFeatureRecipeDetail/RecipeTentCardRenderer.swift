#if os(iOS) && canImport(UIKit)
import DODDomain
import SwiftUI
import UIKit

/// DUT-977 — renders the at-the-table tent card to a PNG.
enum RecipeTentCardRenderer {

    /// "<slug>-tent-card.png"; "recipe-tent-card.png" when the slug is empty.
    static func filename(for recipe: Recipe) -> String {
        let base = recipe.slug.isEmpty ? "recipe" : recipe.slug
        return "\(base)-tent-card.png"
    }

    @MainActor
    static func pngData(content: TentCardContent) -> Data? {
        let view = RecipeTentCardView(content: content, qrImage: QRCodeImage.make(from: content.qrPayload))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer.uiImage?.pngData()
    }

    /// Writes the PNG into the temporary directory and returns its URL; nil if rendering or writing fails.
    @MainActor
    static func writeFile(recipe: Recipe, hostName: String?) -> URL? {
        let content = TentCardContent(recipe: recipe, hostName: hostName)
        guard let data = pngData(content: content) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename(for: recipe))
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
#endif
