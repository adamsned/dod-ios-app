import Foundation

/// DUT-177 — which slice of the cook journal a Cooking Wrapped recap covers.
public enum CookingWrappedPeriod: Equatable, Sendable {
    case calendarYear(Int)
    case yearSoFar(asOf: Date)

    /// Half-open range [start, end). Nil only if the calendar can't build it.
    public func range(calendar: Calendar = .current) -> (start: Date, end: Date)? {
        switch self {
        case .calendarYear(let year):
            guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
                let end = calendar.date(byAdding: .year, value: 1, to: start)
            else { return nil }
            return (start, end)
        case .yearSoFar(let now):
            let year = calendar.component(.year, from: now)
            guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
                let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            else { return nil }
            return (start, end)
        }
    }

    /// Entries whose `cookedAt` falls inside the period.
    public func filter(_ entries: [CookLogEntry], calendar: Calendar = .current) -> [CookLogEntry] {
        guard let periodRange = range(calendar: calendar) else { return [] }
        return entries.filter { $0.cookedAt >= periodRange.start && $0.cookedAt < periodRange.end }
    }
}
