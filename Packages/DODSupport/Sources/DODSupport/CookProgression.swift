import Foundation

/// The transformation pillar (North Star): a cook's history isn't just a count —
/// it's an identity they grow into. `CookProgression` maps the total number of
/// logged cooks onto a named rank ladder that climbs toward the brand itself
/// ("Dutch Oven Daddy"), so the Cooking Journal can show how far the cook has
/// come AND the next rung pulling them forward. Pure value logic; the rung
/// names/thresholds in ``ranks`` are the single editable source of brand voice.
public struct CookRank: Equatable, Sendable, Identifiable {

    /// The user-facing rank name (brand voice).
    public let title: String
    /// A playful badge for the rank.
    public let emoji: String
    /// The minimum number of logged cooks required to hold this rank.
    public let threshold: Int

    /// Stable identity for SwiftUI item-based presentation (thresholds are unique).
    public var id: Int { threshold }

    public init(title: String, emoji: String, threshold: Int) {
        self.title = title
        self.emoji = emoji
        self.threshold = threshold
    }
}

public enum CookProgression {

    /// **Daddy Mode (owner rank).** The app owner's fixed Cook Rank — "The Dutch
    /// Oven Daddy". This is NOT a rung on the earnable ``ranks`` ladder: it's an
    /// owner override, held from the very first launch regardless of cook count,
    /// and never celebrated as a "rank up". Resolve a user's shown rank through
    /// ``displayRank(totalCooks:isOwner:)`` — the owner always gets this; everyone
    /// else climbs ``ranks``. Its ``CookRank/threshold`` is the sentinel
    /// ``ownerRankThreshold`` (below every real rung), so it can never be produced
    /// by ``currentRank(totalCooks:)`` / ``rankUp(from:to:)`` from a cook count.
    public static let dutchOvenDaddy = CookRank(
        title: "The Dutch Oven Daddy",
        emoji: "👑",
        threshold: ownerRankThreshold
    )

    /// Sentinel ``CookRank/threshold`` for the owner rank — deliberately below
    /// every real rung so the owner rank stays out of all ladder math and is never
    /// inserted into ``ranks``.
    public static let ownerRankThreshold = -1

    /// The rank ladder, ascending by threshold. EDIT HERE to retune the journey's
    /// names / pacing — every other value derives from this single source.
    public static let ranks: [CookRank] = [
        CookRank(title: "Fire Starter", emoji: "🔥", threshold: 1),
        CookRank(title: "Coal Tender", emoji: "🪵", threshold: 3),
        CookRank(title: "Lid Lifter", emoji: "🍳", threshold: 5),
        CookRank(title: "Cast Iron Convert", emoji: "🛡️", threshold: 10),
        CookRank(title: "Coal Whisperer", emoji: "💨", threshold: 20),
        CookRank(title: "Pit Boss", emoji: "🔱", threshold: 35),
        CookRank(title: "Cast Iron Legend", emoji: "🏆", threshold: 50),
    ]

    /// The highest rank the cook currently holds — `nil` before the first cook.
    public static func currentRank(totalCooks: Int) -> CookRank? {
        ranks.last { totalCooks >= $0.threshold }
    }

    /// The rank to DISPLAY for a user everywhere a rank appears (profile hero,
    /// their own comments): the owner always shows the fixed ``dutchOvenDaddy``
    /// rank — auto-applied from the start, at any cook count — while everyone else
    /// shows their earned ladder rank (`nil` before their first cook). Folds the
    /// old separate owner badge INTO the rank: the owner's rank IS "The Dutch Oven
    /// Daddy", not a ladder rank plus a badge.
    public static func displayRank(totalCooks: Int, isOwner: Bool) -> CookRank? {
        isOwner ? dutchOvenDaddy : currentRank(totalCooks: totalCooks)
    }

    /// The next rank to climb toward — `nil` once the top rung is reached.
    public static func nextRank(totalCooks: Int) -> CookRank? {
        ranks.first { totalCooks < $0.threshold }
    }

    /// Cooks remaining to reach the next rank — `nil` at the top.
    public static func cooksToNextRank(totalCooks: Int) -> Int? {
        nextRank(totalCooks: totalCooks).map { max(0, $0.threshold - totalCooks) }
    }

    /// Progress (0...1) from the current rung's threshold toward the next rung's;
    /// 1.0 once the top rung is reached.
    public static func progressToNextRank(totalCooks: Int) -> Double {
        guard let next = nextRank(totalCooks: totalCooks) else { return 1.0 }
        let floor = currentRank(totalCooks: totalCooks)?.threshold ?? 0
        let span = next.threshold - floor
        guard span > 0 else { return 0 }
        return min(1.0, max(0.0, Double(totalCooks - floor) / Double(span)))
    }

    /// The rank newly REACHED when the cook count goes from `before` to `after`
    /// (e.g. logging a cook) — `nil` if no rung threshold was crossed. Drives the
    /// milestone celebration: a cook that bumps you up a rank is a moment, not a
    /// silent increment.
    public static func rankUp(from before: Int, to after: Int) -> CookRank? {
        guard after > before else { return nil }
        let reached = currentRank(totalCooks: after)
        return reached != currentRank(totalCooks: before) ? reached : nil
    }
}
