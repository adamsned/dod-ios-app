#if os(iOS) && canImport(UIKit)
import DODDomain
import SwiftUI
import UIKit

/// DUT-123: rasterizes RecipeImageCardView and writes a PNG for the share sheet.
enum RecipeImageCardRenderer {

    @MainActor
    static func render(
        recipe: Recipe,
        heroImage: UIImage?,
        logo: UIImage?,
        scheme: ColorScheme = .light
    ) -> UIImage? {
        let content = ImageCardContent(recipe: recipe)
        let view = RecipeImageCardView(
            content: content,
            heroImage: heroImage,
            logo: logo,
            qrImage: QRCodeImage.make(from: content.qrPayload)
        )
        .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage
    }

    /// Writes the PNG into the temp dir as "<slug>-card.png"; nil on failure.
    static func writePNG(_ image: UIImage, slug: String) -> URL? {
        guard let data = image.pngData() else { return nil }
        let base = slug.isEmpty ? "recipe" : slug
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(base)-card.png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
#endif
