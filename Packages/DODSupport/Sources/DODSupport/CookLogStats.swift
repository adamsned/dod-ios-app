import Foundation

/// Pure, host-free statistics over a set of ``CookLogEntry`` (US-48 / DUT-104).
///
/// These are the numbers the cook journal's "My Kitchen" view and the habit
/// features (cooking streak DUT-171, badges DUT-175, "Cooking Wrapped" DUT-177)
/// render. Pure + `Calendar`-injected so every value is deterministically
/// unit-testable with fixed dates and no time-zone surprises.
public enum CookLogStats {

    /// A recipe + how many times it's been cooked (most-cooked result).
    public struct RecipeFrequency: Equatable, Sendable {
        public let recipeID: Int
        public let title: String
        public let count: Int
    }

    /// A calendar month + how many cooks fell in it (busiest-month result).
    public struct MonthFrequency: Equatable, Sendable {
        public let year: Int
        public let month: Int
        public let count: Int
    }

    /// Total number of cook-log entries.
    public static func totalCooks(_ entries: [CookLogEntry]) -> Int {
        entries.count
    }

    /// DUT-625 / DUT-685 — the cook count that feeds the RANK ladder: the journal
    /// minus off-path dump-cake cooks. Product assumption: dump cakes are "Anytime
    /// Treats" off the guided path, and graduation is path-only, so a first-ever
    /// dump cake must NOT earn a rank the path population wouldn't. This is the
    /// SINGLE source of truth for the rank population so the rank DISPLAY (Cooking
    /// Journal + Settings profile) and the rank-up CELEBRATION can never diverge
    /// (DUT-685 — they previously counted different populations). Distinct from
    /// ``totalCooks(_:)``, which stays the true "total cooks" stat everywhere it's
    /// shown.
    public static func rankLadderCookCount(_ entries: [CookLogEntry]) -> Int {
        let dumpCakeRecipeIDs = Set(DumpCake.all.map(\.id))
        return entries.filter { !dumpCakeRecipeIDs.contains($0.recipeID) }.count
    }

    /// Average of the user's own 1–5 personal ratings across cook-log entries
    /// (DUT-882 — iOS parity: Android's cook journal stats summary). Only
    /// entries that carry a personal rating count; an un-rated cook doesn't
    /// drag the average toward zero. `nil` when nothing has been rated yet, so
    /// the UI can show a placeholder rather than a misleading "0.0".
    public static func averageRating(_ entries: [CookLogEntry]) -> Double? {
        let ratings = entries.compactMap(\.personalRating)
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }

    /// Number of cooks logged in the trailing 30-calendar-day window ending
    /// "today" — today plus the previous 29 days (DUT-882 — iOS parity:
    /// Android's cook journal stats summary). The window start is calendar-day
    /// based (via `startOfDay`) so time-of-day can't shift an entry in or out,
    /// and entries after `now` (clock skew / bad data) are excluded rather than
    /// over-counted.
    public static func cooksInLast30Days(
        _ entries: [CookLogEntry],
        asOf now: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard
            let windowStart = calendar.date(
                byAdding: .day,
                value: -29,
                to: calendar.startOfDay(for: now)
            )
        else {
            return 0
        }
        return entries.reduce(into: 0) { count, entry in
            if entry.cookedAt >= windowStart && entry.cookedAt <= now { count += 1 }
        }
    }

    /// How many times a specific recipe has been cooked ("made 4×").
    public static func timesCooked(recipeID: Int, in entries: [CookLogEntry]) -> Int {
        entries.reduce(into: 0) { count, entry in
            if entry.recipeID == recipeID { count += 1 }
        }
    }

    /// The most-cooked recipe. Ties break toward the most recently cooked, then
    /// the lower recipe id, for determinism. Nil when there are no entries.
    public static func mostCooked(_ entries: [CookLogEntry]) -> RecipeFrequency? {
        guard !entries.isEmpty else { return nil }
        var tallies: [Int: Tally] = [:]
        for entry in entries {
            if var existing = tallies[entry.recipeID] {
                existing.count += 1
                existing.lastCooked = max(existing.lastCooked, entry.cookedAt)
                tallies[entry.recipeID] = existing
            } else {
                tallies[entry.recipeID] = Tally(
                    title: entry.recipeTitle,
                    count: 1,
                    lastCooked: entry.cookedAt
                )
            }
        }
        let best = tallies.max { lhs, rhs in
            if lhs.value.count != rhs.value.count { return lhs.value.count < rhs.value.count }
            if lhs.value.lastCooked != rhs.value.lastCooked {
                return lhs.value.lastCooked < rhs.value.lastCooked
            }
            return lhs.key > rhs.key  // lower id wins the tie
        }
        guard let best else { return nil }
        return RecipeFrequency(recipeID: best.key, title: best.value.title, count: best.value.count)
    }

    /// The current **weekly** cooking streak: the run of consecutive calendar
    /// weeks — counting back from the week containing `now` — that each have at
    /// least one cook. The in-progress current week is *forgiving*: if it has no
    /// cook yet, the streak is anchored at last week so an empty Monday doesn't
    /// zero a real streak (DUT-171's grace rule). Returns 0 when neither the
    /// current nor the previous week has a cook.
    public static func currentWeeklyStreak(
        _ entries: [CookLogEntry],
        asOf now: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard !entries.isEmpty else { return 0 }
        let weeksWithCooks = Set(entries.map { weekStart(of: $0.cookedAt, calendar: calendar) })
        let currentWeek = weekStart(of: now, calendar: calendar)
        guard let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek)
        else { return 0 }

        // Grace: anchor at the current week if it has a cook, else last week.
        var anchor = weeksWithCooks.contains(currentWeek) ? currentWeek : previousWeek
        guard weeksWithCooks.contains(anchor) else { return 0 }

        var streak = 0
        while weeksWithCooks.contains(anchor) {
            streak += 1
            guard let prior = calendar.date(byAdding: .weekOfYear, value: -1, to: anchor) else {
                break
            }
            anchor = prior
        }
        return streak
    }

    /// The month with the most cooks. Ties break toward the more recent month.
    /// Nil when there are no entries.
    public static func busiestMonth(
        _ entries: [CookLogEntry],
        calendar: Calendar = .current
    ) -> MonthFrequency? {
        guard !entries.isEmpty else { return nil }
        var counts: [DateComponents: Int] = [:]
        for entry in entries {
            let components = calendar.dateComponents([.year, .month], from: entry.cookedAt)
            counts[components, default: 0] += 1
        }
        let best = counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            // Tie → more recent (year, then month) wins.
            let lhsKey = (lhs.key.year ?? 0) * 12 + (lhs.key.month ?? 0)
            let rhsKey = (rhs.key.year ?? 0) * 12 + (rhs.key.month ?? 0)
            return lhsKey < rhsKey
        }
        guard let best, let year = best.key.year, let month = best.key.month else { return nil }
        return MonthFrequency(year: year, month: month, count: best.value)
    }

    // MARK: - Private

    private struct Tally {
        var title: String
        var count: Int
        var lastCooked: Date
    }

    /// Start-of-week date for a given instant, used to bucket entries by week.
    private static func weekStart(of date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }
}
