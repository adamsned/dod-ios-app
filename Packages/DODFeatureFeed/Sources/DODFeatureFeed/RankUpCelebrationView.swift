import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-323 — the milestone celebration. When a logged cook bumps the cook up a
/// rank (`CookProgression.rankUp`), this is the moment that makes the
/// transformation *felt* instead of a silent increment. Presented as a sheet
/// from `FeedView` when `FeedViewModel.rankUpCelebration` is set.
struct RankUpCelebrationView: View {

    let rank: CookRank
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: DODSpacing.md) {
            Spacer()
            Text(rank.emoji)
                .font(.system(size: 88))
                .accessibilityHidden(true)
            Text("Rank up")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.burntOrange)
                .textCase(.uppercase)
                .tracking(2)
            Text("You're a \(rank.title)")
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DODSpacing.md)
            Spacer()
            Button("Keep cooking") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .tint(DODColor.burntOrange)
        }
        .padding(DODSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DODColor.surface.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank up. You're a \(rank.title).")
    }

    /// The top rung gets its own line — no coupling to the rank's name, so a
    /// retune of `CookProgression.ranks` keeps working.
    private var subtitle: String {
        let isTopRung = rank.threshold == CookProgression.ranks.last?.threshold
        return isTopRung
            ? "You climbed the whole path. You made it to the top. 👑"
            : "Every cook makes you better. Keep the fire going."
    }
}
