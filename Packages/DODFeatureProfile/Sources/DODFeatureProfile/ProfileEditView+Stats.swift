import DODDesignSystem
import DODSupport
import SwiftUI

// DUT-417 / CL-292 — the profile "stats" surface, shown in read-only view mode
// between the identity fields and Sign Out. Three parts (the locked "combo of
// 2 and 3"): a Cook Rank hero (derived from `totalCooks` via `CookProgression`),
// a counts grid (Total Cooks / Weekly Streak / Saved Recipes / Ratings), and a
// "View Cooking Journal" link. Rendered only when `loadStats` is wired (the
// composition root supplies it); previews / snapshot hosts pass nil → hidden.
extension ProfileEditView {

    /// The stats section. Renders once `loadedStats` resolves; the body's
    /// `.task` calls `loadStats` and assigns it.
    @ViewBuilder
    var profileStatsSection: some View {
        if let stats = loadedStats {
            Section {
                VStack(alignment: .leading, spacing: DODSpacing.md) {
                    rankHero(stats: stats)
                    countsGrid(stats: stats)
                }
                .padding(.vertical, DODSpacing.xs)

                if statsHooks?.viewCookingJournal != nil {
                    journalLink
                }
            } header: {
                Text("Cooking Journal")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            .listRowBackground(DODColor.surfaceElevated)
        }
    }

    // MARK: - Rank hero

    /// Cook Rank hero: the current rank's emoji + title, a progress caption, and
    /// (mid-climb) a progress bar toward the next rank.
    private func rankHero(stats: ProfileStats) -> some View {
        // DUT-685 — the Cook Rank derives from the path-only `rankLadderCooks`, the
        // SAME population the rank-up celebration counts, so the visible rank and
        // the next celebration can't contradict. `totalCooks` still feeds the
        // "Total Cooks" cell below.
        let rankCooks = stats.rankLadderCooks
        let rank = CookProgression.currentRank(totalCooks: rankCooks)
        let climbing =
            rankCooks > 0
            && CookProgression.nextRank(totalCooks: rankCooks) != nil
        return HStack(spacing: DODSpacing.md) {
            Text(rank?.emoji ?? "🍳")
                .font(.system(size: 44))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                Text(rank?.title ?? "Your Cook Rank")
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.labelStrong)
                Text(Self.rankProgressCaption(totalCooks: rankCooks))
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if climbing {
                    ProgressView(value: CookProgression.progressToNextRank(totalCooks: rankCooks))
                        .tint(DODColor.accent)
                }
                // Daddy Mode (Phase 1, cosmetic) — the standout owner badge under
                // the name/rank area. Gated OFF for everyone until Dad's real
                // `sub` is configured in `OwnerGate`; display-only.
                if isCurrentUserOwner {
                    OwnerBadge()
                        .padding(.top, DODSpacing.xxs)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Pure copy helper for the rank hero's caption — `static` so the L1 suite
    /// can pin the three states (no cooks / climbing / top rank) without a host.
    static func rankProgressCaption(totalCooks: Int) -> String {
        guard totalCooks > 0 else {
            return "Log your first cook to start climbing the ranks."
        }
        guard let next = CookProgression.nextRank(totalCooks: totalCooks) else {
            return "Top rank reached. You're a true Cast Iron Legend."
        }
        // `nextRank` non-nil ⇒ `cooksToNextRank` non-nil (both nil only at top).
        let remaining = CookProgression.cooksToNextRank(totalCooks: totalCooks) ?? 0
        let noun = remaining == 1 ? "cook" : "cooks"
        return "\(remaining) more \(noun) to \(next.emoji) \(next.title)"
    }

    // MARK: - Counts grid

    /// 2-column grid of stat cells. The Ratings cell is omitted when
    /// `reviewsWritten` is nil (not locally countable).
    private func countsGrid(stats: ProfileStats) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: DODSpacing.sm) {
            statCell(value: stats.totalCooks, label: "Total Cooks")
            statCell(value: stats.weeklyStreak, label: "Weekly Streak")
            statCell(value: stats.savedRecipes, label: "Saved Recipes")
            if let reviews = stats.reviewsWritten {
                statCell(value: reviews, label: reviews == 1 ? "Rating" : "Ratings")
            }
        }
    }

    private func statCell(value: Int, label: String) -> some View {
        VStack(spacing: DODSpacing.xxs) {
            Text("\(value)")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
            Text(label)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DODSpacing.sm)
        .background(DODColor.surface, in: RoundedRectangle(cornerRadius: DODRadius.inner))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Journal link

    private var journalLink: some View {
        Button {
            statsHooks?.viewCookingJournal?()
        } label: {
            HStack {
                Text("View Cooking Journal")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.accent)
                Spacer()
                Image(systemName: "chevron.right")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("profile-view-journal")
    }
}
