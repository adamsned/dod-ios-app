import Foundation

/// Deterministic, non-AI rubric for the next rung (DUT-1030). Doubles as the
/// cold-start default and the fallback when Apple Intelligence is unavailable.
public enum NextRungScorer {
    public static let longGapDays = 21
    public static let lowRatingThreshold = 2
    public static let coldStartCooks = 3

    public enum Reason: Equatable, Sendable {
        case coldStart
        case easedAfterGap(days: Int)
        case easedAfterLowRating(Int)
        case steppingUp
    }

    public struct Scored: Equatable, Sendable {
        public let candidate: NextRungCandidate
        public let score: Double
        public let reason: Reason
    }

    public static func isColdStart(_ signals: NextRungSignals) -> Bool {
        signals.totalCooks < coldStartCooks
    }

    /// The difficulty to aim for, plus why. `easier` drops the target one more notch.
    public static func target(
        signals: NextRungSignals,
        lastCookedDifficulty: Int?,
        easier: Bool
    ) -> (difficulty: Int, reason: Reason) {
        let base = lastCookedDifficulty ?? 1
        var difficulty: Int
        let reason: Reason
        if isColdStart(signals) {
            difficulty = 1
            reason = .coldStart
        } else if let gapDays = signals.daysSinceLastCook, gapDays >= longGapDays {
            difficulty = base
            reason = .easedAfterGap(days: gapDays)
        } else if let rating = signals.lastRating, rating <= lowRatingThreshold {
            difficulty = base
            reason = .easedAfterLowRating(rating)
        } else {
            difficulty = min(5, base + 1)
            reason = .steppingUp
        }
        if easier { difficulty = max(1, difficulty - 1) }
        return (difficulty, reason)
    }

    /// Candidates best-first. Never-cooked recipes beat repeats; ties break on lower recipeID.
    public static func rank(
        _ candidates: [NextRungCandidate],
        signals: NextRungSignals,
        lastCookedDifficulty: Int?,
        easier: Bool = false
    ) -> [Scored] {
        let aim = target(signals: signals, lastCookedDifficulty: lastCookedDifficulty, easier: easier)
        return
            candidates
            .map { candidate in
                let repeatPenalty = signals.cookedRecipeIDs.contains(candidate.recipeID) ? 4.0 : 0
                let score = 10 - 3 * Double(abs(candidate.difficulty - aim.difficulty)) - repeatPenalty
                return Scored(candidate: candidate, score: score, reason: aim.reason)
            }
            .sorted {
                $0.score != $1.score ? $0.score > $1.score : $0.candidate.recipeID < $1.candidate.recipeID
            }
    }
}
