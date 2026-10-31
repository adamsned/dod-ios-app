import Foundation

/// DUT-103 — a meal slot within a planned day.
public enum MealSlot: String, Codable, Sendable, CaseIterable {
    case breakfast, lunch, dinner, snack
}

/// DUT-103 — week-boundary helpers for the Meal Planner.
public enum MealPlanWeek {
    /// Start-of-day of the first day of the week containing `date`.
    public static func weekStart(for date: Date, calendar: Calendar = .current) -> Date {
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
        return interval?.start ?? calendar.startOfDay(for: date)
    }

    /// The 7 start-of-day dates of the week beginning at `weekStart`.
    public static func days(inWeekStarting weekStart: Date, calendar: Calendar = .current) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    /// `weekStart` shifted by `weeks` (negative = earlier). Used for paging.
    public static func weekStart(byAdding weeks: Int, to weekStart: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .weekOfYear, value: weeks, to: weekStart) ?? weekStart
    }
}
