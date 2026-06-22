import DODDesignSystem
import SwiftUI

/// DUT-200 / T-834 — the onboarding "speech bubble" that points up at the Feed's
/// Cooking Tools menu button (`frying.pan.fill`). Replaces the big "Your First
/// Cookout" hero card (DUT-183) as the Feed's single onboarding nudge: rather
/// than spotlighting one cook, it orients a newcomer to the whole Cooking Tools
/// menu (start your first cookout, dial in the coals, care for your cast iron)
/// so they discover every cooking-help + cast-iron-care tool in one place.
///
/// Dismissible + persisted (`dod.cookingToolsCalloutDismissed`) so it nudges
/// once and then gets out of the way; the menu button itself stays for re-entry.
struct CookingToolsCallout: View {

    let onDismiss: () -> Void

    /// Height of the upward tail; also the extra top inset so content clears it.
    private static let tailHeight: CGFloat = 9

    var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            HStack(spacing: DODSpacing.xs) {
                // No icon here: the toolbar button is already the `frying.pan.fill`,
                // and the tail points right at it, so a second pan in the bubble
                // would be redundant. The orange title carries the association.
                Text("Cooking Tools")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.burntOrange)
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DODColor.labelSecondary)
                        .padding(DODSpacing.xxs)
                }
                .accessibilityLabel("Dismiss")
                .accessibilityIdentifier("feed-cooking-tools-callout-dismiss")
            }
            Text(
                "Tap here to start your first cookout, dial in the coals, and care for "
                    + "your cast iron. Your toolkit for every step as your Dutch oven skills grow."
            )
            .dodFont(DODType.detail)
            .foregroundStyle(DODColor.labelSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DODSpacing.md)
        .padding(.top, Self.tailHeight)
        .background(
            SpeechBubble(tailHeight: Self.tailHeight)
                .fill(DODColor.surfaceElevated)
        )
        .overlay(
            SpeechBubble(tailHeight: Self.tailHeight)
                .stroke(DODColor.burntOrange.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feed-cooking-tools-callout")
    }
}

/// A rounded-rectangle bubble with a small triangular tail near the TRAILING
/// edge of the top, so it reads as pointing up at the trailing-edge toolbar
/// button it sits beneath.
private struct SpeechBubble: Shape {
    var cornerRadius: CGFloat = 14
    var tailWidth: CGFloat = 18
    var tailHeight: CGFloat = 9
    /// Distance from the trailing edge to the tail's center.
    var tailInsetFromTrailing: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bodyTop = rect.minY + tailHeight
        let radius = min(cornerRadius, (rect.height - tailHeight) / 2)
        let tailCenterX = max(rect.minX + radius + tailWidth, rect.maxX - tailInsetFromTrailing)

        path.move(to: CGPoint(x: rect.minX + radius, y: bodyTop))
        path.addLine(to: CGPoint(x: tailCenterX - tailWidth / 2, y: bodyTop))
        path.addLine(to: CGPoint(x: tailCenterX, y: rect.minY))
        path.addLine(to: CGPoint(x: tailCenterX + tailWidth / 2, y: bodyTop))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: bodyTop))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: bodyTop + radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: bodyTop + radius))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: bodyTop + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    CookingToolsCallout(onDismiss: {})
        .frame(width: 280)
        .padding()
        .background(DODColor.surface)
}
