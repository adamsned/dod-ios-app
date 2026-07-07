import Foundation

/// Snapshot of the profile "stats" surfaced in read-only view mode (DUT-417 /
/// CL-292), shown between the identity fields and Sign Out. A pure value type
/// assembled by the composition root from cook logs + saved recipes + ratings;
/// the view derives the Cook Rank from `rankLadderCooks` (the path-only count)
/// via `CookProgression` (DODSupport). All counts are local-only — nothing
/// leaves the device.
public struct ProfileStats: Equatable, Sendable {

    /// Total logged cooks — the true "Total Cooks" stat cell (all cooks, incl.
    /// off-path dump cakes).
    public let totalCooks: Int
    /// DUT-685 — the path-only cook count that drives the Cook Rank hero
    /// (`CookLogStats.rankLadderCookCount`: total minus off-path dump cakes). Must
    /// match the population the rank-up CELEBRATION counts so the visible rank and
    /// the next celebration never contradict. Defaults to `totalCooks` so any
    /// caller that only supplies `totalCooks` keeps its prior behavior.
    public let rankLadderCooks: Int
    /// Consecutive-weeks cooking streak (`CookLogStats.currentWeeklyStreak`).
    public let weeklyStreak: Int
    /// Number of saved recipes.
    public let savedRecipes: Int
    /// Star ratings the user has written; `nil` when not countable, which
    /// hides that one grid cell rather than showing a misleading zero.
    public let reviewsWritten: Int?

    public init(
        totalCooks: Int,
        rankLadderCooks: Int? = nil,
        weeklyStreak: Int,
        savedRecipes: Int,
        reviewsWritten: Int?
    ) {
        self.totalCooks = totalCooks
        // Default the rank population to `totalCooks` so existing callers that
        // don't yet distinguish path-only cooks keep their prior behavior; the
        // composition root (SettingsViewModel+Stats) passes the real path-only
        // count for DUT-685.
        self.rankLadderCooks = rankLadderCooks ?? totalCooks
        self.weeklyStreak = weeklyStreak
        self.savedRecipes = savedRecipes
        self.reviewsWritten = reviewsWritten
    }

    /// All-zero placeholder (no cooks yet / unwired host).
    public static let empty = ProfileStats(
        totalCooks: 0,
        rankLadderCooks: 0,
        weeklyStreak: 0,
        savedRecipes: 0,
        reviewsWritten: nil
    )
}

/// Composition-root hooks that light up the profile stats section (DUT-417):
/// an async stats loader plus an optional "View Cooking Journal" callback.
/// Bundled into one optional `ProfileEditView` parameter so the init stays under
/// the SwiftLint `function_parameter_count` cap. Nil at the call site (previews /
/// snapshots / unwired hosts) hides the whole section.
public struct ProfileStatsHooks {

    /// Loads the current stats. Called once on appear in view mode.
    public let load: @MainActor () async -> ProfileStats
    /// Presents the full Cooking Journal. Nil hides the "View Cooking Journal"
    /// link (the rank + counts still show).
    public let viewCookingJournal: (@MainActor () -> Void)?

    public init(
        load: @escaping @MainActor () async -> ProfileStats,
        viewCookingJournal: (@MainActor () -> Void)? = nil
    ) {
        self.load = load
        self.viewCookingJournal = viewCookingJournal
    }
}
