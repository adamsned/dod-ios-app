import Foundation

/// DUT-157 — decides whether the automatic App Store review prompt may be shown. Pure; no I/O.
public enum ReviewPromptPolicy {
    public static let minSessions = 4
    public static let minRecipeViews = 8
    public static let minCompletedCooks = 1
    /// Our own conservative cooldown, on top of Apple's 3-per-365-days system cap.
    public static let cooldown: TimeInterval = 120 * 24 * 60 * 60

    public struct Snapshot: Sendable, Equatable {
        public var sessionCount: Int
        public var recipeViewCount: Int
        public var completedCookCount: Int
        public var lastPromptDate: Date?
        public var declined: Bool
        public var isCooking: Bool  // active cook / timer
        public var hadRecentError: Bool

        public init(
            sessionCount: Int,
            recipeViewCount: Int,
            completedCookCount: Int,
            lastPromptDate: Date? = nil,
            declined: Bool = false,
            isCooking: Bool = false,
            hadRecentError: Bool = false
        ) {
            self.sessionCount = sessionCount
            self.recipeViewCount = recipeViewCount
            self.completedCookCount = completedCookCount
            self.lastPromptDate = lastPromptDate
            self.declined = declined
            self.isCooking = isCooking
            self.hadRecentError = hadRecentError
        }
    }

    public static func isEligible(_ snapshot: Snapshot, now: Date = Date()) -> Bool {
        if snapshot.declined || snapshot.isCooking || snapshot.hadRecentError { return false }
        if snapshot.sessionCount < minSessions { return false }  // also blocks first launch
        if let last = snapshot.lastPromptDate, now.timeIntervalSince(last) < cooldown { return false }
        return snapshot.completedCookCount >= minCompletedCooks
            || snapshot.recipeViewCount >= minRecipeViews
    }
}
