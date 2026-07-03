import SwiftUI

/// DUT-461 — the in-app card shown when the Cooking Tip widget is tapped
/// (DUT-457). Styled to match `CookingToolsCallout` rather than a system
/// `.alert`: a rounded `surfaceElevated` card with a burnt-orange hairline
/// stroke, an orange "Cooking Tip" title (flame icon) + an X dismiss, and the
/// full tip body. Presentation (the dimmed scrim + centering + transition) is
/// the caller's job; this is just the card so it stays L4-snapshot-testable.
public struct TipDialogCard: View {

    let tip: String
    let onDismiss: () -> Void

    public init(tip: String, onDismiss: @escaping () -> Void) {
        self.tip = tip
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            HStack(spacing: DODSpacing.xxs) {
                Image(systemName: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DODColor.burntOrange)
                Text("Cooking Tip")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.burntOrange)
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DODColor.labelSecondary)
                        .padding(DODSpacing.xxs)
                        .frame(minWidth: 44, minHeight: 44)  // 44pt tap target
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dismiss")
                .accessibilityIdentifier("cooking-tip-dialog-dismiss")
            }
            Text(tip)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DODSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DODRadius.standard)
                .fill(DODColor.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DODRadius.standard)
                .stroke(DODColor.burntOrange.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cooking-tip-dialog")
    }
}

#Preview {
    TipDialogCard(tip: "Rotate the oven a third of a turn each time you check it", onDismiss: {})
        .frame(width: 300)
        .padding()
        .background(DODColor.surface)
}
