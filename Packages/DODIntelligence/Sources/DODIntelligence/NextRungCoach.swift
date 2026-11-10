import DODSupport
import Foundation

public struct NextRungRecommendation: Sendable, Equatable {
    public let candidate: NextRungCandidate
    public let why: String
    public let isColdStart: Bool

    public init(candidate: NextRungCandidate, why: String, isColdStart: Bool) {
        self.candidate = candidate
        self.why = why
        self.isColdStart = isColdStart
    }
}

/// On-device next-rung coach (DUT-1030). Returns recommendations best-first (the
/// carousel); the first is the headline pick. Never throws; [] when no candidates.
public protocol NextRungCoaching: Sendable {
    func recommend(
        candidates: [NextRungCandidate],
        signals: NextRungSignals,
        lastCookedDifficulty: Int?,
        easier: Bool
    ) async -> [NextRungRecommendation]
}

/// Non-AI scorer-backed coach: the cold-start default and the no-Apple-Intelligence fallback.
public struct DeterministicNextRungCoach: NextRungCoaching {
    public init() {}

    public func recommend(
        candidates: [NextRungCandidate],
        signals: NextRungSignals,
        lastCookedDifficulty: Int?,
        easier: Bool
    ) async -> [NextRungRecommendation] {
        NextRungScorer.rank(
            candidates,
            signals: signals,
            lastCookedDifficulty: lastCookedDifficulty,
            easier: easier
        )
        .map { Self.recommendation(for: $0) }
    }

    static func recommendation(for scored: NextRungScorer.Scored) -> NextRungRecommendation {
        NextRungRecommendation(
            candidate: scored.candidate,
            why: whyLine(scored.reason),
            isColdStart: scored.reason == .coldStart
        )
    }

    static func whyLine(_ reason: NextRungScorer.Reason) -> String {
        switch reason {
        case .coldStart:
            return "A friendly first step while we learn what you like to cook."
        case .easedAfterGap(let days):
            return "It's been \(days) days, so let's ease back in at your level."
        case .easedAfterLowRating(let rating):
            return "Your last cook only got \(rating) stars, so we're keeping this one steady."
        case .steppingUp:
            return "You're on a roll, so here's the next step up."
        }
    }
}
