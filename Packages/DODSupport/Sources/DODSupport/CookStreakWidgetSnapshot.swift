import Foundation

/// DUT-169 — derived stats for the Cook Streak widget. Pure; no I/O.
public struct CookStreakStats: Equatable, Sendable {
    public let streakDays: Int
    public let weekDots: [Bool]
    public let cooksThisWeek: Int
    public let hasAnyCooks: Bool

    public init(streakDays: Int, weekDots: [Bool], cooksThisWeek: Int, hasAnyCooks: Bool) {
        self.streakDays = streakDays
        self.weekDots = weekDots
        self.cooksThisWeek = cooksThisWeek
        self.hasAnyCooks = hasAnyCooks
    }

    /// Consecutive cooked days ending today, or yesterday if today has no cook yet.
    static func streak(days: Set<Date>, now: Date, calendar: Calendar) -> Int {
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor), let prev = calendar.date(byAdding: .day, value: -1, to: cursor) {
            cursor = prev
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    public static let empty = CookStreakStats(
        streakDays: 0,
        weekDots: Array(repeating: false, count: 7),
        cooksThisWeek: 0,
        hasAnyCooks: false
    )
}
