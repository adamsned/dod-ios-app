import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-976 — the shareable multi-dish recap card.
struct CookoutRecapCard: View {
    let headline: String
    let dishTitles: [String]
    let averageRatingText: String?  // e.g. "4.3", nil when unrated
    let cover: Image?

    static let size = CGSize(width: 360, height: 640)
    static let maxListedDishes = 6

    /// Titles shown on the card, with a "+N more" tail when truncated.
    static func visibleDishLines(_ titles: [String]) -> [String] {
        guard titles.count > maxListedDishes else { return titles }
        return Array(titles.prefix(maxListedDishes)) + ["+\(titles.count - maxListedDishes) more"]
    }

    var body: some View {
        ZStack {
            DODColor.surface
            VStack(spacing: DODSpacing.md) {
                Group {
                    if let cover {
                        cover.resizable().scaledToFill()
                    } else {
                        DODColor.burntOrange.opacity(0.15)
                            .overlay(
                                Image(systemName: "flame.fill").font(.system(size: 64)).foregroundStyle(
                                    DODColor.burntOrange
                                )
                            )
                    }
                }
                .frame(height: 320)
                .clipped()
                Text(headline).dodFont(DODType.heading).foregroundStyle(DODColor.label).multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    ForEach(Self.visibleDishLines(dishTitles), id: \.self) { line in
                        Text("• \(line)").dodFont(DODType.body).foregroundStyle(DODColor.label)
                    }
                }
                if let averageRatingText {
                    Text("Avg rating \(averageRatingText)").dodFont(DODType.caption).foregroundStyle(
                        DODColor.labelSecondary
                    )
                }
                Spacer(minLength: 0)
            }
            .padding(DODSpacing.md)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}
