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
            hero
                .frame(height: 1000)
                .clipped()
            VStack(alignment: .leading, spacing: DODSpacing.lg) {
                Text(content.title)
                    .font(.system(size: 72, weight: .bold, design: .serif))
                    .foregroundStyle(DODColor.label)
                    .minimumScaleFactor(0.5)
                    .lineLimit(3)
                if !content.stats.isEmpty {
                    Text(content.stats.joined(separator: "  ·  "))
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(DODColor.burntOrange)
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: DODSpacing.lg) {
                    VStack(alignment: .leading, spacing: DODSpacing.xs) {
                        if let logo {
                            Image(uiImage: logo)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                        }
                        Text(content.linkText)
                            .font(.system(size: 34))
                            .foregroundStyle(DODColor.labelSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if let qrImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 240, height: 240)
                            .accessibilityLabel("QR code for \(content.title)")
                    }
                }
            }
            .padding(DODSpacing.xl * 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
        .background(DODColor.cream)
    }

    @ViewBuilder private var hero: some View {
        if let heroImage {
            Image(uiImage: heroImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                DODColor.castIronBrown
                if let logo {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 400)
                }
            }
        }
    }
}
#endif
