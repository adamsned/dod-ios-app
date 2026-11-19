import Foundation

public enum HouseholdPortionCheck {
    public enum Verdict: Equatable, Sendable {
        case noData  // no servings or empty roster
        case scaleUp(needed: Int, have: Int)
        case justEnough
        case leftovers(extraPortions: Int)  // >= 1 spare adult portion
    }

    /// Appetite weight in adult-portion units. Unknown age band counts as an adult.
    public static func weight(_ band: AgeBand?) -> Double {
        switch band {
        case .littleKid: 0.5
        case .kid: 0.75
        case .teenOrAdult, .none: 1.0
        }
    }

    public static func verdict(members: [HouseholdMember], servings: Int?) -> Verdict {
        guard let servings, servings > 0, !members.isEmpty else { return .noData }
        let need = members.reduce(0.0) { $0 + weight($1.ageBand) }
        let needed = Int(need.rounded(.up))
        if servings < needed { return .scaleUp(needed: needed, have: servings) }
        let spare = servings - needed
        return spare >= 1 ? .leftovers(extraPortions: spare) : .justEnough
    }

    public static func message(for verdict: Verdict) -> String? {
        switch verdict {
        case .noData: nil
        case .scaleUp(let needed, let have): "Serves \(have) - your table needs about \(needed). Scale up."
        case .justEnough: "About right for your table."
        case .leftovers(let extra): "Plenty for your table + \(extra) leftover portion\(extra == 1 ? "" : "s")."
        }
    }
}
