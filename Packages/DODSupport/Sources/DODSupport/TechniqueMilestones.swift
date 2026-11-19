import DODDomain
import Foundation

/// DUT-973 — transferable technique milestones, earned from real logged cooks.
public struct TechniqueMilestone: Equatable, Sendable, Identifiable {
    public let technique: Technique
    /// Logged cooks that exercised this technique.
    public let reps: Int
    public var id: String { technique.rawValue }
}

public enum TechniqueMilestones {

    /// Cooks of a technique required before it counts as earned.
    public static let repsToEarn = 2

    /// Techniques earned from the cook log, in `Technique.allCases` order.
    public static func earned(from entries: [CookLogEntry]) -> [TechniqueMilestone] {
        var counts: [Technique: Int] = [:]
        for entry in entries {
            for technique in Technique.detect(in: entry.recipeTitle) {
                counts[technique, default: 0] += 1
            }
        }
        return Technique.allCases.compactMap { technique in
            let reps = counts[technique, default: 0]
            return reps >= repsToEarn ? TechniqueMilestone(technique: technique, reps: reps) : nil
        }
    }

    /// "You've now seared, braised, and baked in cast iron." `nil` when none earned.
    public static func summary(_ milestones: [TechniqueMilestone]) -> String? {
        let verbs = milestones.map(\.technique.pastTense)
        switch verbs.count {
        case 0: return nil
        case 1: return "You've now \(verbs[0]) in cast iron."
        case 2: return "You've now \(verbs[0]) and \(verbs[1]) in cast iron."
        default:
            let head = verbs.dropLast().joined(separator: ", ")
            return "You've now \(head), and \(verbs[verbs.count - 1]) in cast iron."
        }
    }
}
