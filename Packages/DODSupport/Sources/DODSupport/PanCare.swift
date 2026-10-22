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
