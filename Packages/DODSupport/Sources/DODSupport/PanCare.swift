import Foundation

/// DUT-971 — the "wipe, oil, done — 30 seconds" post-cook care steps.
public enum PanCareStep: String, CaseIterable, Sendable, Codable, Equatable {
    case wipe, oil, done

    public var title: String {
        switch self {
        case .wipe: return "Wipe"
        case .oil: return "Oil"
        case .done: return "Done"
        }
    }
    public var instruction: String {
        switch self {
        case .wipe: return "Wipe the warm pan clean with a paper towel or stiff brush. No soap needed."
        case .oil: return "Rub a few drops of cooking oil over the inside, then buff off the excess."
        case .done: return "That's it. Your pan is ready for next time."
        }
    }
}

/// One logged maintenance session.
public struct PanCareEntry: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let careAt: Date
    public init(id: UUID = UUID(), careAt: Date) {
        self.id = id
        self.careAt = careAt
    }
}

public enum PanCare {
    /// Days without a cook or care before a gentle re-seasoning nudge.
    public static let idleDaysThreshold = 21

    /// Most recent cook or care date, or nil if neither exists.
    public static func lastActivity(cooks: [CookLogEntry], cares: [PanCareEntry]) -> Date? {
        (cooks.map(\.cookedAt) + cares.map(\.careAt)).max()
    }

    /// True when the pan has been idle >= `idleDaysThreshold` days. A user with
    /// NO cooks and NO care entries is never nudged (nothing to season yet).
    public static func isIdle(
        cooks: [CookLogEntry],
        cares: [PanCareEntry],
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let last = lastActivity(cooks: cooks, cares: cares) else { return false }
        let days = calendar.dateComponents([.day], from: last, to: now).day ?? 0
        return days >= idleDaysThreshold
    }
}
