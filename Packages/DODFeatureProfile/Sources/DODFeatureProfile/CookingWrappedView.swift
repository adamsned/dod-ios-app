import DODDesignSystem
import SwiftUI

/// DUT-177 — stack of recap cards. Private by default; nothing is shared
/// unless the user taps the share button.
public struct CookingWrappedView: View {
    let cards: [CookingWrappedCard]
    let onViewed: () -> Void
    let onShare: () -> Void

    public init(cards: [CookingWrappedCard], onViewed: @escaping () -> Void = {}, onShare: @escaping () -> Void = {}) {
        self.cards = cards
        self.onViewed = onViewed
        self.onShare = onShare
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: DODSpacing.md) {
                ForEach(cards) { card in
                    CookingWrappedCardView(card: card)
                }
                if cards.count > 1 {
                    Button("Share my recap", action: onShare)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("cookingWrapped.share")
                }
            }
            .padding(DODSpacing.md)
        }
        .onAppear(perform: onViewed)
    }
}

struct CookingWrappedCardView: View {
    let card: CookingWrappedCard
    var body: some View {
        VStack(spacing: DODSpacing.xs) {
            Text(card.emoji).font(.system(size: 44)).accessibilityHidden(true)
            Text(card.headline).dodFont(DODType.heading)
            Text(card.detail).dodFont(DODType.caption).foregroundStyle(DODColor.labelSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(DODSpacing.md)
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
