import Foundation

public struct FireCircleBoard: Sendable, Equatable {
    public private(set) var cooks: [String: FireCircleCook] = [:]
    public init() {}

    /// Keep only the newest `sentAt` per peer; ignore older packets.
    public mutating func apply(_ cook: FireCircleCook) {
        if let existing = cooks[cook.peerID], existing.sentAt >= cook.sentAt { return }
        cooks[cook.peerID] = cook
    }
    public mutating func remove(peerID: String) { cooks[peerID] = nil }

    /// Soonest-finishing first. Paused cooks sort after running ones, then by cookName.
    /// Completed cooks come first.
    public func sorted(now: Date) -> [FireCircleCook] {
        cooks.values.sorted { cook1, cook2 in
            let remaining1 = cook1.remaining(now: now)
            let remaining2 = cook2.remaining(now: now)

            // Completed cooks come first
            if cook1.isCompleted && !cook2.isCompleted {
                return true
            } else if !cook1.isCompleted && cook2.isCompleted {
                return false
            }

            // If both are completed, sort by remaining time (ascending)
            if cook1.isCompleted && cook2.isCompleted {
                return remaining1 < remaining2
            }

            // For non-completed cooks:
            // If one is paused and the other isn't, paused comes after running
            if !cook1.isPaused && cook2.isPaused {
                return true
            } else if cook1.isPaused && !cook2.isPaused {
                return false
            }

            // Both are either running or paused - sort by remaining time (ascending)
            return remaining1 < remaining2
        }
    }
}

extension FireCircleCook {
    /// Seconds left: from `endDate` when running, else the stored `remainingSeconds`. Never below 0.
    public func remaining(now: Date) -> Int {
        guard !isPaused, let endDate else { return max(remainingSeconds, 0) }
        return max(Int(endDate.timeIntervalSince(now).rounded(.up)), 0)
    }
}
