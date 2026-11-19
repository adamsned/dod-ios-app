import Foundation

/// DUT-975 — how much challenge the next suggested rep should carry, derived from
/// the user's recent private confidence reads.
public enum ChallengeBias: String, Sendable, Equatable {
    case easier, same, harder
}

public enum ConfidenceChallengeBias {

    /// Looks at the 3 most recent confidence reads (newest by `cookedAt`).
    /// Average <= 2.0 returns .easier (felt hard). Average >= 4.0 returns .harder
    /// (felt easy). Fewer than 2 reads, or anything in between, returns .same.
    public static func bias(for entries: [CookLogEntry]) -> ChallengeBias {
        let recent = CookLogStats.confidenceTrajectory(entries).suffix(3).map { Double($0.confidence) }
        guard recent.count >= 2 else { return .same }
        let average = recent.reduce(0, +) / Double(recent.count)
        if average <= 2.0 { return .easier }
        if average >= 4.0 { return .harder }
        return .same
    }
}
