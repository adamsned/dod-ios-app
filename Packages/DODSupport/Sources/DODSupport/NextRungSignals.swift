import Foundation

/// On-device summary of a cook's real history, used to calibrate the next rung
/// (DUT-1030). Pure; never leaves the phone.
public struct NextRungSignals: Sendable, Equatable {
    public let totalCooks: Int
    public let daysSinceLastCook: Int?
    public let lastRating: Int?
    public let weeklyStreak: Int
    public let cooksToNextRank: Int?
    public let cookedRecipeIDs: Set<Int>
    public let lastCookedRecipeID: Int?

    public init(
        totalCooks: Int,
        daysSinceLastCook: Int?,
        lastRating: Int?,
        weeklyStreak: Int,
        cooksToNextRank: Int?,
        cookedRecipeIDs: Set<Int>,
        lastCookedRecipeID: Int?
    ) {
        self.totalCooks = totalCooks
        self.daysSinceLastCook = daysSinceLastCook
        self.lastRating = lastRating
        self.weeklyStreak = weeklyStreak
        self.cooksToNextRank = cooksToNextRank
        self.cookedRecipeIDs = cookedRecipeIDs
        self.lastCookedRecipeID = lastCookedRecipeID
    }

    public static func make(
        entries: [CookLogEntry],
        asOf now: Date,
        calendar: Calendar = .current
    ) -> NextRungSignals {
        let total = CookLogStats.rankLadderCookCount(entries)
        let last = entries.max { $0.cookedAt < $1.cookedAt }
        let days: Int? = last.map {
            max(
                0,
                calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: $0.cookedAt),
                    to: calendar.startOfDay(for: now)
                ).day ?? 0
            )
        }
        return NextRungSignals(
            totalCooks: total,
            daysSinceLastCook: days,
            lastRating: last?.personalRating,
            weeklyStreak: CookLogStats.currentWeeklyStreak(entries, asOf: now, calendar: calendar),
            cooksToNextRank: CookProgression.cooksToNextRank(totalCooks: total),
            cookedRecipeIDs: Set(entries.map(\.recipeID)),
            lastCookedRecipeID: last?.recipeID
        )
    }
}
