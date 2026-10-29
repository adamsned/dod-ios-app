#if os(iOS) && canImport(UIKit)
import SwiftUI
import UIKit

/// DUT-977 — the at-the-table tent card: dish name, byline, scannable QR.
struct RecipeTentCardView: View {

    /// 4x6 in at 72 pt/in, landscape-friendly for a folded tent.
    static let cardSize = CGSize(width: 432, height: 288)

    let content: TentCardContent
    let qrImage: UIImage?

    private let ink = Color(red: 0.13, green: 0.13, blue: 0.13)
    private let orange = Color(red: 197 / 255, green: 106 / 255, blue: 36 / 255)

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(content.dishName)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(3)
                Text(content.byline)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(orange)
                Text("Scan for the recipe")
                    .font(.system(size: 12))
                    .foregroundStyle(ink.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 130, height: 130)
                    .accessibilityLabel("QR code for \(content.dishName)")
            }
        }
        .padding(24)
        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
        .background(Color.white)
    }
}
#endif
