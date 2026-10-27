import Foundation

/// DUT-103 — a meal slot within a planned day.
public enum MealSlot: String, Codable, Sendable, CaseIterable {
    case breakfast, lunch, dinner, snack
}
