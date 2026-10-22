import Foundation

/// DUT-970 — calm, cast-iron-specific rescues for the classic mid-cook failures.
/// Pure content (no UI) so Cook Mode and any future surface can reuse it.
public enum CastIronRescue {

    public enum Problem: String, CaseIterable, Sendable, Hashable, Identifiable {
        case sticking, tooHot, underdoneCenter, flareUp, browningTooFast
        public var id: String { rawValue }

        /// Chip / row label shown to the cook.
        public var title: String {
            switch self {
            case .sticking: return "Food is sticking"
            case .tooHot: return "Pan is running too hot"
            case .underdoneCenter: return "Center is still raw"
            case .flareUp: return "Flare-up!"
            case .browningTooFast: return "Browning too fast"
            }
        }
    }

    public struct Rescue: Equatable, Sendable {
        public let problem: Problem
        /// One reassuring sentence, Ned's voice.
        public let reassurance: String
        /// 2-4 short, ordered fixes.
        public let steps: [String]
    }

    public static func rescue(for problem: Problem) -> Rescue {
        let reassurance: String
        let steps: [String]

        switch problem {
        case .sticking:
            reassurance = "Happens to everyone. Don't force it, it'll let go when it's ready."
            steps = [
                "Leave it alone 30 to 60 seconds more; a good crust releases itself.",
                "Slide a thin spatula under gently, don't pry.",
                "Add a teaspoon of oil around the edge and let it heat.",
            ]
        case .tooHot:
            reassurance = "Easy fix. Cast iron holds heat, so we just back off."
            steps = [
                "Pull the pan off the heat for a minute.",
                "Move a few coals off the lid or from under the oven.",
                "Crack the lid or vents slightly to bleed heat.",
            ]
        case .underdoneCenter:
            reassurance = "Totally fine. The outside is done, the middle just needs time."
            steps = [
                "Lower the heat and put the lid back on.",
                "Give it 5 to 10 more minutes and check again.",
                "Tent with foil if the top is already dark.",
            ]
        case .flareUp:
            reassurance = "Stay calm. Fat caught fire, you didn't ruin dinner."
            steps = [
                "Put the lid on to smother the flame.",
                "Move the pan off direct heat.",
                "Never use water on a grease flare-up.",
            ]
        case .browningTooFast:
            reassurance = "You're ahead of schedule on color, not behind."
            steps = [
                "Move the pan to a cooler spot or lift it off the coals.",
                "Tent loosely with foil.",
                "Rotate the pan so one side isn't taking all the heat.",
            ]
        }

        return Rescue(problem: problem, reassurance: reassurance, steps: steps)
    }

    /// All rescues in display order.
    public static var all: [Rescue] { Problem.allCases.map(rescue(for:)) }
}
