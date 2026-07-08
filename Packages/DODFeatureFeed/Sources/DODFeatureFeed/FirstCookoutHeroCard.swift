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
    let onCookDumpCake: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            HStack(spacing: DODSpacing.xs) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(DODColor.burntOrange)
                    .accessibilityHidden(true)  // DUT — decorative eyebrow glyph
                Text(heroEyebrow)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.burntOrange)
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DODColor.labelSecondary)
                        .padding(DODSpacing.xxs)
                        // DUT — a ~20pt glyph+padding is below the 44pt minimum;
                        // enlarge the hit target without changing the visual.
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dismiss")
                .accessibilityIdentifier("feed-first-cookout-hero-dismiss")
            }
            Text(heroTitle)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
            Text(heroHook)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onStart) {
                Text("Let's Cook")
                    .frame(maxWidth: .infinity)
            }
            .dodProminentButton()
            .tint(DODColor.burntOrange)
            .padding(.top, DODSpacing.xxs)
            Button(action: onCookDumpCake) {
                Text("Or Cook a Dump Cake")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.burntOrange)
                    // DUT — a bare caption row is a ~20pt target; give it a full
                    // 44pt height so the tap area meets the a11y minimum.
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("feed-hero-dump-cake")
        }
        .padding(DODSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .strokeBorder(DODColor.burntOrange.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feed-first-cookout-hero")
    }

    private var heroEyebrow: String {
        if cookout.isCampfire { return "YOU'RE READY" }
        return cookout.isFirstRung ? "START HERE" : "YOUR NEXT WIN"
    }

    private var heroTitle: String {
        if cookout.isCampfire { return cookout.dishTitle }
        return cookout.isFirstRung ? "Your First Cookout" : "Your Next Cookout"
    }

    private var heroHook: String {
        if cookout.isCampfire {
            return
                "You've earned this one. Take a dish you've already nailed and cook it "
                + "outdoors, over a real fire, for the people you love. This is the moment "
                + "they remember."
        }
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
    FirstCookoutHeroCard(cookout: .firstCookout, onStart: {}, onDismiss: {}, onCookDumpCake: {})
        .padding()
}
