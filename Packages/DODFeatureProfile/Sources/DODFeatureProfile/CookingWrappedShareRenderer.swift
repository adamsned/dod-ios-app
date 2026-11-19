import CoreGraphics
import SwiftUI

/// DUT-177 — renders the recap cards to a local CGImage for a user-initiated share.
public enum CookingWrappedShareRenderer {
    @MainActor
    public static func render(cards: [CookingWrappedCard], scale: CGFloat = 2) -> CGImage? {
        guard !cards.isEmpty else { return nil }
        let content = VStack(spacing: 12) {
            ForEach(cards) { CookingWrappedCardView(card: $0) }
        }
        .padding(24)
        .frame(width: 390)
        .background(Color.white)
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        return renderer.cgImage
    }
}
