import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-323 — a celebratory moment surfaced after a logged cook. Graduating the
/// whole First Cookout path is the bigger beat (it's the first-win → identity
/// payoff), so it takes priority over a plain rank-up.
public enum CookCelebration: Equatable, Identifiable, Sendable {
    /// A logged cook bumped the cook up a rank on the ladder.
    case rankUp(CookRank)
    /// A logged cook completed the whole First Cookout path (every rung cooked).
    case graduatedFirstCookout

    public var id: String {
        switch self {
        case .rankUp(let rank): return "rank-\(rank.threshold)"
        case .graduatedFirstCookout: return "graduated"
        }
    }
}

/// The celebration sheet, presented when `FeedViewModel.celebration` is set —
/// the moment that makes the transformation *felt* instead of a silent journal
/// increment. T-912 / DUT-551 (CL-306) — `public` so the app-level Cooking Tools
/// hub, which now presents "Your First Cookout" (the flow that logs the cook
/// and earns the celebration), can render it too.
public struct CookCelebrationView: View {

    let celebration: CookCelebration
    let onDismiss: () -> Void

    public init(celebration: CookCelebration, onDismiss: @escaping () -> Void) {
        self.celebration = celebration
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: DODSpacing.md) {
            Spacer()
            // The celebratory message — combined into a single VO element so it
            // reads eyebrow + title + subtitle in one swipe. The dismiss CTA is
            // kept OUTSIDE this group so `.combine` can't swallow its action.
            VStack(spacing: DODSpacing.md) {
                Text(emoji)
                    .font(.system(size: 88))
                    .accessibilityHidden(true)
                Text(eyebrow)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.burntOrange)
                    .textCase(.uppercase)
                    .tracking(2)
                Text(title)
                    .dodFont(DODType.displayMedium)
                    .foregroundStyle(DODColor.label)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DODSpacing.md)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Button(buttonTitle) { onDismiss() }
                .dodProminentButton()
                .tint(DODColor.burntOrange)
        }
        .padding(DODSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DODColor.surface.ignoresSafeArea())
    }

    private var emoji: String {
        switch celebration {
        case .rankUp(let rank): return rank.emoji
        case .graduatedFirstCookout: return "🎓"
        }
    }

    private var eyebrow: String {
        switch celebration {
        case .rankUp: return "Rank up"
        case .graduatedFirstCookout: return "Path complete"
        }
    }

    private var title: String {
        switch celebration {
        case .rankUp(let rank): return "You're a \(rank.title)"
        case .graduatedFirstCookout: return "You're a Dutch Oven Cook"
        }
    }

    private var subtitle: String {
        switch celebration {
        case .rankUp(let rank):
            // The top rung gets its own line — derived from `ranks.last`, not the
            // name, so a retune of `CookProgression.ranks` keeps working.
            let isTopRung = rank.threshold == CookProgression.ranks.last?.threshold
            return isTopRung
                ? "You climbed the whole path. You made it to the top. 👑"
                : "Every cook makes you better. Keep the fire going."
        case .graduatedFirstCookout:
            return "You cooked every dish on the path, from your first cookout to the "
                + "campfire. That's not beginner stuff anymore."
        }
    }

    private var buttonTitle: String {
        switch celebration {
        case .rankUp: return "Keep Cooking"
        case .graduatedFirstCookout: return "What's Next"
        }
    }
}
