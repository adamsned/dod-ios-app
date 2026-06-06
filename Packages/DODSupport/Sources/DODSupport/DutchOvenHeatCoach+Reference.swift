import Foundation

// The cook-by-feel reference content for the Dutch Oven Heat Coach (DUT-48),
// lifted from Dutch Oven Daddy's published method (the
// `/dutch-oven-temperature-chart/` page). Exposed as structured data so the
// `HeatCoachView` renders one source of truth rather than re-typing the copy
// in the view layer. Split out of `DutchOvenHeatCoach.swift` so that file
// stays under the 400-line `file_length` cap.
//
// These payloads are pinned by `DutchOvenHeatCoachTests` — a paraphrase that
// drops the substance (not just the wording) trips CI, which is intentional:
// the feel cues ARE the feature, so they don't get to silently shrink.

/// One cook-by-feel cue: a sense to watch, what "on track" looks like, and
/// what to do when it drifts. The whole adapt-by-feel loop in one row.
public struct FeelCue: Equatable, Sendable, Identifiable {
    /// Stable identity for SwiftUI `ForEach` — the `title` is unique across
    /// the cue set, so it doubles as the id.
    public var id: String { title }
    /// The sense / signal, e.g. "Coal color" or "Hand test".
    public let title: String
    /// What it looks/sounds/smells like when the heat is right.
    public let onTrack: String
    /// What it looks like when it's drifting, and the fix.
    public let adjust: String

    public init(title: String, onTrack: String, adjust: String) {
        self.title = title
        self.onTrack = onTrack
        self.adjust = adjust
    }
}

extension DutchOvenHeatCoach {

    /// The cook-by-feel cues — the heart of the feature. Each pairs an
    /// "on track" read with an "adjust" fix so the cook learns to steer by
    /// the oven, not the chart.
    public static let feelCues: [FeelCue] = [
        FeelCue(
            title: "Coal color",
            onTrack: "White-gray ash coating means steady, optimal heat.",
            adjust:
                "Bright orange glow = running hot; pull 1-2 coals from the bottom. "
                + "Dark or dull = spent; replenish from the chimney."
        ),
        FeelCue(
            title: "Steam at the lid rim",
            onTrack: "A light wisp escaping the lid is normal.",
            adjust: "Heavy, continuous steam = too hot or too much liquid. Ease the bottom heat."
        ),
        FeelCue(
            title: "Hand test",
            onTrack: "Palm held over the coals: 4-5s = 325-350°F, 2-3s = 375-425°F.",
            adjust: "Under 2 seconds is too hot for most recipes — pull coals before you load the oven."
        ),
        FeelCue(
            title: "Sound",
            onTrack: "A gentle, consistent sizzle is right.",
            adjust: "Rapid popping or spattering = reduce heat; pull coals from the bottom first."
        ),
        FeelCue(
            title: "Smell",
            onTrack: "A light caramel smell means it's browning, not burning.",
            adjust: "Scorching before the halfway mark = the bottom is burning; pull bottom coals now."
        ),
        FeelCue(
            title: "Lid condensation",
            onTrack: "Moisture beading on the underside of the lid means a healthy, moist cook.",
            adjust: "Bone-dry at the 30-minute mark = running hot and dry; ease off and check the food."
        ),
    ]

    /// The coal-management habits that keep heat steady across a long cook —
    /// the routine behind the feel cues.
    public static let coalManagementHabits: [String] = [
        "Keep a charcoal chimney going so the next round of coals is always lighting.",
        "Rotate the oven and the lid a quarter-turn (in opposite directions) every 15 minutes to even out hot spots.",
        "Replenish when coals are 60-70% spent — glowing with thin ash, not gray and cold.",
        "Replace coals from the bottom and top in pairs so the lid/bottom ratio holds.",
        "In wind, reposition the oven or build a windbreak before you reach for more coals.",
    ]

    /// Wind-specific guidance — wind is the single biggest disruptor of a
    /// Dutch oven cook, so fix the environment before adding fuel.
    public static let windGuidance: [String] = [
        "Orient the oven back-to-wind so the gusts don't blow heat off the windward coals.",
        "Build a windbreak — rocks, a camp table, or a cooler on the upwind side.",
        "On windy days, replenish every 20 min instead of 30; coals burn down faster in moving air.",
    ]
}
