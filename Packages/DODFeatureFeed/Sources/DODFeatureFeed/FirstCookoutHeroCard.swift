import DODDesignSystem
import DODSupport
import SwiftUI

/// The "Start Here" hero card at the top of the Feed (DUT-183) — promotes the
/// keystone "Your First Cookout" flow so a nervous beginner actually *finds*
/// the coached path, instead of relying on the easy-to-miss toolbar flame.
///
/// This is the strategy's front door: the whole one-guaranteed-win wedge only
/// works if people see it. Dismissible (persisted) so a cook who's past their
/// first win isn't nagged — the toolbar flame stays for re-entry.
struct FirstCookoutHeroCard: View {

    let cookout: GuidedCookout
    let onStart: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            HStack(spacing: DODSpacing.xs) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(DODColor.burntOrange)
                Text(cookout.isFirstRung ? "START HERE" : "YOUR NEXT WIN")
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
                .accessibilityIdentifier("feed-first-cookout-hero-dismiss")
            }
            Text(cookout.isFirstRung ? "Your First Cookout" : "Your Next Cookout")
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
            Text(heroHook)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onStart) {
                Text("Let's cook")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(DODColor.burntOrange)
            .padding(.top, DODSpacing.xxs)
        }
        .padding(DODSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DODSpacing.md, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DODSpacing.md, style: .continuous)
                .strokeBorder(DODColor.burntOrange.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feed-first-cookout-hero")
    }

    private var heroHook: String {
        if cookout.isFirstRung {
            return
                "One guaranteed win: \(cookout.dishTitle). I'll walk you through every step. "
                + "The coals, the timing, all of it. You've got this."
        }
        return
            "Ready for your next one? \(cookout.dishTitle). Even more forgiving than your "
            + "first. Let's keep the streak going."
    }
}

#Preview {
    FirstCookoutHeroCard(cookout: .firstCookout, onStart: {}, onDismiss: {})
        .padding()
}
