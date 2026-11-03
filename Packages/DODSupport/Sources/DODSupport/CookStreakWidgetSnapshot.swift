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

    /// Seven flags, first weekday of `calendar` first; true where that day has a cook.
    static func weekDots(days: Set<Date>, now: Date, calendar: Calendar) -> [Bool] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return Array(repeating: false, count: 7)
        }
        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: week.start) else { return false }
            return days.contains(calendar.startOfDay(for: day))
        }
    }

    /// Total cook events inside the calendar week containing `now`.
    static func cooksThisWeek(cookDates: [Date], now: Date, calendar: Calendar) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return cookDates.filter { week.contains($0) }.count
    }

    public static let empty = CookStreakStats(
        streakDays: 0,
        weekDots: Array(repeating: false, count: 7),
        cooksThisWeek: 0,
        hasAnyCooks: false
    )
}
