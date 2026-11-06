import Foundation

/// DUT-152 — pure decision logic for the opt-in weekly new-recipes digest.
public enum WeeklyDigestGate {

    /// Minimum gap between two digests ("one per week maximum").
    public static let minimumInterval: TimeInterval = 7 * 24 * 60 * 60

    /// Quiet hours: 21:00 (inclusive) to 08:00 (exclusive), local hour.
    public static let quietStartHour = 21
    public static let quietEndHour = 8

    /// True when `hour` (0...23) falls inside quiet hours (the window wraps midnight).
    public static func isQuietHour(_ hour: Int) -> Bool {
        hour >= quietStartHour || hour < quietEndHour
    }

    /// True when a digest may be sent now.
    /// - `newRecipeCount == 0` -> false (no empty digests).
    /// - `lastSentAt` within `minimumInterval` of `now` -> false (never double-fires).
    /// - `now` inside quiet hours (in `calendar`) -> false.
    public static func shouldSend(
        newRecipeCount: Int,
        lastSentAt: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard newRecipeCount > 0 else { return false }
        if let lastSentAt, now.timeIntervalSince(lastSentAt) < minimumInterval { return false }
        return !isQuietHour(calendar.component(.hour, from: now))
    }
}
