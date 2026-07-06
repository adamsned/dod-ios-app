import DODSupport
import Foundation

/// Pure presentation model for ``HeatCoachView`` (DUT-48). Maps the calc core
/// (``DutchOvenHeatCoach``) plus the user's input selections into the exact
/// display strings the screen renders — keeping the math-to-copy mapping
/// testable on the macOS slice without a snapshot host, and keeping the view
/// files thin under the `file_length` cap.
///
/// Self-contained by design: no data model, no persistence, no network. The
/// inputs are plain value types the SwiftUI screen holds in `@State`; this
/// struct is rebuilt on every change.
///
/// Framing contract (DUT-48): everything here is "a starting point, not a
/// rule." The result headline says so, and the adjustment lines lead the cook
/// toward the feel cues rather than implying a fixed answer.
struct HeatCoachModel {

    /// The oven sizes the picker offers, in inches. Matches the common cast
    /// iron Dutch oven range DOD writes for.
    static let ovenSizes: [Int] = [8, 10, 12, 14, 16]

    let ovenDiameterInches: Int
    let style: CookingStyle
    let elevationFeet: Int
    let ambient: AmbientCondition
    let windy: Bool

    // MARK: - Derived: the starting estimate

    var coalSplit: CoalSplit {
        DutchOvenHeatCoach.startingCoals(ovenDiameterInches: ovenDiameterInches, style: style)
    }

    /// The condition coal delta applied to the starting estimate: the ambient
    /// (air-temperature) adjustment PLUS the wind adjustment, summed. Elevation
    /// is deliberately excluded — it changes cook TIME, not coal count. Mild +
    /// calm → `0...0` (no change).
    var conditionCoalDelta: ClosedRange<Int> {
        let ambientDelta = DutchOvenHeatCoach.ambientCoalDelta(ambient)
        let windDelta = DutchOvenHeatCoach.windCoalDelta(windy)
        return (ambientDelta.lowerBound + windDelta.lowerBound)...(ambientDelta.upperBound + windDelta.upperBound)
    }

    /// The starting split ADJUSTED for the current conditions (DUT-600): the
    /// base ``coalSplit`` total shifted by a representative (midpoint) of
    /// ``conditionCoalDelta``, re-split by ``style`` via the same public
    /// even/baking splitters — so the answer diagram MOVES when the cook sets a
    /// hot / cold / windy day. At mild + calm the delta is `0...0`, so this
    /// equals ``coalSplit`` and the default answer is unchanged. The precise
    /// per-condition ranges still surface in the "What Changes" notes; this is
    /// the single "starting point" number the diagram shows.
    var adjustedCoalSplit: CoalSplit {
        let delta = conditionCoalDelta
        // DUT-653: round the midpoint to nearest-EVEN, not away-from-zero. The
        // default `.rounded()` rounds a .5 midpoint away from zero, so a cold
        // 2...3 (mid 2.5) biased UP to 3 and a hot -3...-2 (mid -2.5) biased
        // DOWN to -3 — every asymmetric adjustment skewed to its outer edge.
        // `.toNearestOrEven` gives a true, unbiased midpoint (2.5 → 2, -2.5 → -2).
        let midpoint = Int((Double(delta.lowerBound + delta.upperBound) / 2.0).rounded(.toNearestOrEven))
        let adjustedTotal = max(0, coalSplit.total + midpoint)
        switch style {
        case .even: return DutchOvenHeatCoach.evenSplit(total: adjustedTotal)
        case .baking: return DutchOvenHeatCoach.bakingSplit(total: adjustedTotal)
        }
    }

    /// Headline number line, e.g. "Start with ~24 coals: 18 on the lid, 6 underneath".
    var coalHeadline: String {
        let split = coalSplit
        return
            "Start with ~\(split.total) coals: \(split.lid) on the lid, \(split.bottom) underneath"
    }

    /// One-line note explaining the split for the chosen style.
    var styleNote: String {
        switch style {
        case .even:
            return "Even heat, top and bottom. Great for roasts, stews, and one-pot meals."
        case .baking:
            return
                "Lid-heavy, about 3:1 (3 coals on top for every 1 underneath). "
                + "Great for breads, cobblers, and cakes, so the top browns without burning the bottom."
        }
    }

    // MARK: - Derived: the condition adjustments

    /// Ambient coal-delta line, e.g. "Cold air (about 20-30°F): add 2-3 coals."
    /// Mild returns `nil` so the UI omits a no-op row.
    var ambientNote: String? {
        let delta = DutchOvenHeatCoach.ambientCoalDelta(ambient)
        switch ambient {
        case .mild:
            return nil
        case .hot:
            return
                "Hot out (about 90-100°F): pull \(magnitudePhrase(delta)) coals, "
                + "since the oven already holds plenty of heat."
        case .cold:
            return
                "Cold out (about 20-30°F): add \(magnitudePhrase(delta)) coals, "
                + "since the cold air steals heat."
        }
    }

    /// Elevation extra-time line, e.g. "At 3,000 ft: add 45-60 minutes to the cook."
    /// Returns `nil` at/below the baseline so the UI omits a no-op row.
    var elevationNote: String? {
        let range = DutchOvenHeatCoach.cookTimeExtraMinutes(elevationFeetAboveBaseline: elevationFeet)
        guard range.upperBound > 0 else { return nil }
        let feet = Self.feetFormatter.string(from: NSNumber(value: elevationFeet)) ?? "\(elevationFeet)"
        return "At \(feet) ft: add \(range.lowerBound)-\(range.upperBound) minutes to the cook."
    }

    /// Always-shown cook-time readout for the answer card (DUT-601 — every
    /// input must visibly move the recommendation). Unlike ``elevationNote``
    /// this is never nil: at/below the baseline it states the recipe's usual
    /// time; above it, the elevation-added time. Elevation adjusts cook TIME,
    /// not coal count (the DOD method), so it lives in the answer here rather
    /// than the coal diagram — but changing the elevation stepper still moves
    /// the answer live.
    var elevationCookTimeLine: String {
        let range = DutchOvenHeatCoach.cookTimeExtraMinutes(elevationFeetAboveBaseline: elevationFeet)
        if range.upperBound <= 0 {
            return "Cook for the recipe's usual time."
        }
        let feet = Self.feetFormatter.string(from: NSNumber(value: elevationFeet)) ?? "\(elevationFeet)"
        return "Add \(range.lowerBound)–\(range.upperBound) min for cooking at \(feet) ft."
    }

    /// Replenish-cadence line, always shown.
    var replenishNote: String {
        let minutes = DutchOvenHeatCoach.replenishMinutes(ambient: ambient, windy: windy)
        let why = minutes == 20 ? " (sooner, since coals burn down faster in the cold or wind)" : ""
        return "Replenish from the chimney every \(minutes) minutes\(why)."
    }

    /// Wind coal-delta line, e.g. "Windy: add 3-4 coals, since the wind steals
    /// heat." (DUT-264 — wind adjusts the coal COUNT, not just the replenish
    /// cadence; parallel to ``ambientNote`` and additive with it.) `nil` when calm.
    var windCoalNote: String? {
        guard windy else { return nil }
        let delta = DutchOvenHeatCoach.windCoalDelta(windy)
        return "Windy: add \(magnitudePhrase(delta)) coals, since the wind steals heat."
    }

    /// Wind environment tip — only when windy. Pairs with ``windCoalNote``:
    /// add the coals, but fix the environment first.
    var windNote: String? {
        guard windy else { return nil }
        return
            "Then fix the environment: turn the oven so its back faces the wind, "
            + "and build a windbreak so those coals aren't wasted."
    }

    // MARK: - Helpers

    /// Renders a coal-delta magnitude as a friendly "2-3" phrase (the range
    /// width DOD uses), ignoring sign — the surrounding copy supplies
    /// "add" / "pull".
    private func magnitudePhrase(_ range: ClosedRange<Int>) -> String {
        let low = abs(range.lowerBound)
        let high = abs(range.upperBound)
        let lo = min(low, high)
        let hi = max(low, high)
        return lo == hi ? "\(lo)" : "\(lo)-\(hi)"
    }

    private static let feetFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
