import DODDesignSystem
import SwiftUI

/// DUT-966 — the shareable "capability story" card. Fixed 1080x1350 pt-independent
/// layout (4:5) so ImageRenderer output is the same on every device.
struct CookWinCardView: View {
    static let size = CGSize(width: 360, height: 450)

    let content: CookWinCardContent
    /// The dish photo; nil shows a burnt-orange flame placeholder.
    let photo: Image?

    var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            ZStack {
                if let photo {
                    photo.resizable().scaledToFill()
                } else {
                    Rectangle().fill(DODColor.burntOrange.opacity(0.15))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(DODColor.burntOrange)
                }
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))

            Text(content.headline)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
                .lineLimit(4)
            Text(content.dishTitle)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            Spacer(minLength: 0)
            Text(CookWinCardContent.attribution)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(DODSpacing.md)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(DODColor.surface)
    }
}
