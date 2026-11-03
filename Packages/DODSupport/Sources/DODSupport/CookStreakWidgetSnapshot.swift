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

    public static let empty = CookStreakStats(
        streakDays: 0,
        weekDots: Array(repeating: false, count: 7),
        cooksThisWeek: 0,
        hasAnyCooks: false
    )
}
