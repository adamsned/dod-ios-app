import DODDesignSystem
import DODSupport
import SwiftUI

// DUT-461 (revised) — the persistent Cooking Tip banner, extracted from
// `CookingToolsHubView` for the SwiftLint `type_body_length` cap. It replaces the
// old `dod://tip` full-tip popup dialog: the lock-screen Cooking Tip widget's tap
// now opens the Cooking Tools hub, and this banner (pinned below the header, above
// the tool list) shows the tip.
extension CookingToolsHubView {

    /// A persistent Cooking Tip banner pinned at the top of the hub. Shows today's
    /// tip from the same daily rotation the lock-screen Cooking Tip widget uses, so
    /// tapping that widget lands here on the matching tip. Not dismissible: it's
    /// standing coaching, not a popup.
    var tipBanner: some View {
        HStack(alignment: .top, spacing: DODSpacing.md) {
            Image(systemName: "lightbulb.fill")
                .font(.body)
                .foregroundStyle(DODColor.burntOrange)
                .frame(width: 40, height: 40)
                .background(DODColor.burntOrange.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                Text("COOKING TIP")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.burntOrange)
                Text(CookingTip.tip(for: Date()))
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DODSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .fill(DODColor.burntOrange.opacity(0.08))
        )
        .padding(.horizontal, DODSpacing.md)
        .padding(.top, DODSpacing.sm)
        .padding(.bottom, DODSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hub-cooking-tip-banner")
    }
}
