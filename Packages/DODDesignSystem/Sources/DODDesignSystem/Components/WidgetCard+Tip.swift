import SwiftUI

// DUT-459 — home-screen Cooking Tip card (`.systemSmall` + `.systemMedium`).
// Like the other `WidgetCard` variants it paints NO inner background — the
// widget's `containerBackground(for: .widget)` owns it so Tinted/Clear mode
// tints it; the text renders on the container (legible in `.accented` mode
// without a scrim). Companion to the `.accessoryInline` lock-screen tip
// (DUT-454). Spec trace: DUT-459.
extension WidgetCard {

    /// A daily cooking tip as a home-screen card: a flame eyebrow over the tip.
    /// `isCompact` (the `.systemSmall` square) uses a smaller font + more lines;
    /// the wider `.systemMedium` uses a larger font with fewer lines.
    public struct TipCard: View {

        public let tip: String
        public let isCompact: Bool

        public init(tip: String, isCompact: Bool) {
            self.tip = tip
            self.isCompact = isCompact
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: DODSpacing.xs) {
                Label {
                    Text("Cooking Tip")
                        .font(.system(.caption2, design: .default, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.5)
                } icon: {
                    Image(systemName: "flame.fill")
                        .font(.system(.caption2, weight: .semibold))
                }
                .foregroundStyle(DODColor.burntOrange)

                Text(tip)
                    .font(.system(isCompact ? .subheadline : .title3, design: .default, weight: .semibold))
                    .foregroundStyle(DODColor.label)
                    .lineLimit(isCompact ? 5 : 3)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(DODSpacing.md)
        }
    }
}

#Preview("Tip — small") {
    WidgetCard.TipCard(tip: "2 top coals per inch of oven", isCompact: true)
        .frame(width: 158, height: 158)
}

#Preview("Tip — medium") {
    WidgetCard.TipCard(tip: "Rotate the oven a third of a turn each time you check it", isCompact: false)
        .frame(width: 338, height: 158)
}
