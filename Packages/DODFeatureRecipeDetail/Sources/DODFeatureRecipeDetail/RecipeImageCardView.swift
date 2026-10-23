#if os(iOS) && canImport(UIKit)
import DODDesignSystem
import SwiftUI
import UIKit

/// DUT-123: vertical branded share card, rendered to a 1080x1920 PNG.
struct RecipeImageCardView: View {
    static let cardSize = CGSize(width: 1080, height: 1920)

    let content: ImageCardContent
    let heroImage: UIImage?  // nil renders the branded placeholder
    let logo: UIImage?
    let qrImage: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            hero.frame(height: 1000).clipped()
            Spacer(minLength: 0)
        }
        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
        .background(DODColor.cream)
    }

    @ViewBuilder private var hero: some View {
        if let heroImage {
            Image(uiImage: heroImage).resizable().scaledToFill()
        } else {
            ZStack {
                DODColor.castIronBrown
                if let logo {
                    Image(uiImage: logo).resizable().scaledToFit().frame(width: 400)
                }
            }
        }
    }
}
#endif
