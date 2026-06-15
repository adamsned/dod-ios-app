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
            onTrack: "A white-gray ash coating means the heat is steady and right where you want it.",
            adjust:
                "Glowing bright orange means it's running hot, so pull 1-2 coals off the bottom. "
                + "Dark and dull means they're spent, so add fresh ones from your charcoal chimney."
        ),
        FeelCue(
            title: "Steam at the lid rim",
            onTrack: "A light wisp of steam escaping the lid is normal.",
            adjust: "Heavy, nonstop steam means it's too hot or there's too much liquid, so ease off the bottom heat."
        ),
        FeelCue(
            title: "Hand test",
            onTrack: "Hold your palm over the coals: 4-5 seconds means 325-350°F, 2-3 seconds means 375-425°F.",
            adjust: "Under 2 seconds is too hot for most recipes, so pull a few coals before you load the oven."
        ),
        FeelCue(
            title: "Sound",
            onTrack: "A gentle, steady sizzle is just right.",
            adjust: "Rapid popping or spattering means it's too hot, so pull coals from the bottom first."
        ),
        FeelCue(
            title: "Smell",
            onTrack: "A light caramel smell means it's browning, not burning.",
            adjust:
                "A scorched smell before the halfway point means the bottom is burning, "
                + "so pull the bottom coals right away."
        ),
        FeelCue(
            title: "Lid condensation",
            onTrack: "Moisture beading on the underside of the lid means a healthy, moist cook.",
            adjust:
                "Bone-dry under the lid at the 30-minute mark means it's running hot and dry, "
                + "so ease off and check the food."
        ),
    ]

    /// The coal-management habits that keep heat steady across a long cook —
    /// the routine behind the feel cues.
    public static let coalManagementHabits: [String] = [
        "Keep a charcoal chimney going so your next round of coals is always lighting.",
        "Every 15 minutes, rotate the oven and the lid a quarter-turn in opposite directions to even out hot spots.",
        "Add fresh coals when the old ones are about 60-70% spent: still glowing under thin ash, not gray and cold.",
        "Swap coals top and bottom in pairs so your lid-to-bottom ratio stays put.",
        "In wind, move the oven or build a windbreak before you reach for more coals.",
    ]

    /// Wind-specific guidance — wind is the single biggest disruptor of a
    /// Dutch oven cook, so fix the environment before adding fuel.
    public static let windGuidance: [String] = [
        "Turn the oven back-to-wind (its back to the gusts) so the wind can't blow heat off the coals.",
        "Build a windbreak on the upwind side: rocks, a camp table, or a cooler.",
        "On windy days, add fresh coals every 20 min instead of 30, since they burn down faster in moving air.",
    ]
}
