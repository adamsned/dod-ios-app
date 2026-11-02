#if os(iOS) && canImport(UIKit)
import DODDomain
import SwiftUI
import UIKit

/// DUT-977 — rasterizes RecipeTentCardView and writes a PNG for the at-the-table tent card.
enum RecipeTentCardRenderer {

    @MainActor
    static func render(content: TentCardContent) -> UIImage? {
        let view = RecipeTentCardView(
            content: content,
            qrImage: QRCodeImage.make(from: content.qrPayload)
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage
    }

    /// Writes the PNG into the temp dir as "<slug>-tent-card.png"; nil on failure.
    static func filename(for recipe: Recipe) -> String {
        let base = recipe.slug.isEmpty ? "recipe" : recipe.slug
        return "\(base)-tent-card.png"
    }

    @MainActor
    static func pngData(content: TentCardContent) -> Data? {
        guard let image = render(content: content) else { return nil }
        return image.pngData()
    }

    /// Writes the PNG into the temp dir as "<slug>-tent-card.png"; nil on failure.
    @MainActor
    static func writeFile(recipe: Recipe, hostName: String?) -> URL? {
        let content = TentCardContent(recipe: recipe, hostName: hostName)
        guard let data = pngData(content: content) else { return nil }
        let base = recipe.slug.isEmpty ? "recipe" : recipe.slug
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(base)-tent-card.png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
#endif
