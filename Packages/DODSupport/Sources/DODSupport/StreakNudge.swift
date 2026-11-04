import Foundation

/// DUT-972 — pure decision + copy for the gentle weeknight streak nudge.
public enum StreakNudge {

    public enum Status: Equatable, Sendable {
        /// Cooked this calendar week; nothing to nudge.
        case safe(streak: Int)
        /// Streak alive only via last week's grace; one cook this week keeps it.
        case atRisk(streak: Int)
        /// No live streak (0 weeks).
        case none
    }

    public struct Content: Equatable, Sendable {
        public let title: String
        public let body: String
        /// Smallest next rep, shown on the home surface too.
        public let smallestNextRep: String
    }

    public static let deepLink = "dod://feed"

    public static func status(
        _ entries: [CookLogEntry],
        asOf now: Date,
        calendar: Calendar = .current
    ) -> Status {
        let streak = CookLogStats.currentWeeklyStreak(entries, asOf: now, calendar: calendar)
        guard streak > 0 else { return .none }
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        let cookedThisWeek = entries.contains { week?.contains($0.cookedAt) ?? false }
        return cookedThisWeek ? .safe(streak: streak) : .atRisk(streak: streak)
    }

    /// Nil unless status is `.atRisk`. Warm, non-nagging copy.
    public static func content(for status: Status) -> Content? {
        guard case .atRisk(let streak) = status else { return nil }
        return Content(
            title: "Your streak's alive 🔥",
            body: "\(streak)-week streak — one skillet dish keeps it going.",
            smallestNextRep: "Pick one easy skillet dish this week."
        )
    }

    /// Cap: at most one nudge per 5 days. `lastSent` is persisted by the caller.
    public static let minimumInterval: TimeInterval = 5 * 24 * 60 * 60

    public static func shouldSend(lastSent: Date?, now: Date) -> Bool {
        guard let lastSent else { return true }
        return now.timeIntervalSince(lastSent) >= minimumInterval
    }
}
