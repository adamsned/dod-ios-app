import Foundation

/// Pure, dependency-free engine behind the **Dutch Oven Heat Coach** screen
/// (DUT-48) — a baseline coal estimate, condition adjustments, and a
/// cook-by-feel reference.
///
/// **This is not a coal-count chart.** Dutch Oven Daddy's published method
/// (the `/dutch-oven-temperature-chart/` page) is "stop using the chart;
/// give a starting point, then adapt by feel." Every number here is a
/// *starting point, not a rule* — the UI frames the estimate that way and
/// leads the cook to the feel cues, which are the point of the feature.
///
/// Why this lives in `DODSupport` (not in a feature package): it is a pure
/// value-type calculator (Foundation-only, no UI, no AVFoundation, no
/// network) — exactly the seam pattern of ``StepTimerParser`` and
/// ``TitleSearchMatcher``. Hosting it in the support layer means the screen
/// renders it, the unit suite exercises it on the macOS slice, and any
/// future surface (a Tools tab, an App Intent) reuses the same contract.
///
/// The reference content (feel cues, coal-management habits, wind guidance)
/// is exposed as **structured data** in `DutchOvenHeatCoach+Reference.swift`
/// so the UI has a single source of truth to render.
///
/// Spec trace: DUT-48 (Dutch Oven Heat Coach).
public enum DutchOvenHeatCoach {

    // MARK: - Starting coals (the ~350F baseline)

    /// Recommended starting coal count + lid/bottom split for a given oven
    /// size and cooking style.
    ///
    /// The total is the brand's baseline rule: **`diameter * 2`** coals lands
    /// a ~350°F oven (12" → 24, 10" → 20, 14" → 28, …). The split then depends
    /// on style:
    /// - ``CookingStyle/even`` — heat top and bottom equally (`lid == bottom`;
    ///   an odd total puts the extra coal on the bottom). For roasts, stews,
    ///   one-pots — anything that wants all-around heat.
    /// - ``CookingStyle/baking`` — lid-heavy 3:1 (`lid = round(total * 3/4)`,
    ///   `bottom = total - lid`) so the top browns without scorching the
    ///   bottom. For breads, cobblers, cakes.
    ///
    /// The returned ``CoalSplit`` is a *starting point* — the caller surfaces
    /// it under the "then cook by feel" framing, never as a fixed answer.
    public static func startingCoals(ovenDiameterInches: Int, style: CookingStyle) -> CoalSplit {
        let total = max(0, ovenDiameterInches) * 2
        switch style {
        case .even:
            return evenSplit(total: total)
        case .baking:
            return bakingSplit(total: total)
        }
    }

    /// Balanced lid/bottom split. When `total` is odd the extra coal goes on
    /// the **bottom** (the side that does the structural cooking), so
    /// `bottom >= lid` by at most one.
    ///
    /// Exposed (not private) so the unit suite can pin the odd-total edge
    /// independently of the `diameter * 2` rule, which only ever yields even
    /// totals for an integer diameter.
    public static func evenSplit(total: Int) -> CoalSplit {
        let lid = total / 2
        let bottom = total - lid
        return CoalSplit(lid: lid, bottom: bottom, total: total)
    }

    /// Lid-heavy 3:1 split for baking: `lid = round(total * 3/4)`,
    /// `bottom = total - lid`. Rounds the lid to the nearest whole coal
    /// (10 → 7.5 → 8 lid / 2 bottom).
    ///
    /// Exposed for the same reason as ``evenSplit(total:)`` — direct
    /// boundary coverage.
    public static func bakingSplit(total: Int) -> CoalSplit {
        let lid = Int((Double(total) * 3.0 / 4.0).rounded())
        let bottom = total - lid
        return CoalSplit(lid: lid, bottom: bottom, total: total)
    }

    // MARK: - Ambient condition adjustment (a RANGE, not false precision)

    /// How many coals to add or remove for the air temperature, as a
    /// **range** — DOD says "2-3 coals", so the UI shows a range rather than
    /// a single false-precise number.
    ///
    /// - ``AmbientCondition/hot`` (≈90-100°F) → `-3...-2` (the oven holds
    ///   heat; pull a couple).
    /// - ``AmbientCondition/cold`` (≈20-30°F) → `2...3` (the cold air steals
    ///   heat; add a couple).
    /// - ``AmbientCondition/mild`` → `0...0` (no change).
    public static func ambientCoalDelta(_ condition: AmbientCondition) -> ClosedRange<Int> {
        switch condition {
        case .hot:
            return -3...(-2)
        case .mild:
            return 0...0
        case .cold:
            return 2...3
        }
    }

    // MARK: - Elevation cook-time adjustment

    /// Extra cook time for elevation, as a **range** of minutes:
    /// **+15 to +20 minutes per 1,000 ft** above the chosen baseline.
    ///
    /// Thousands are counted whole (2,500 ft → 2 → `30...40`); anything at or
    /// below the baseline clamps to `0...0` (elevation never *shortens* a
    /// cook). The baseline itself is the caller's reference altitude — pass
    /// `feetAboveBaseline = absoluteElevation - baseline`; the default
    /// baseline is sea level (0 ft).
    public static func cookTimeExtraMinutes(elevationFeetAboveBaseline feet: Int) -> ClosedRange<Int> {
        let thousands = max(0, feet) / 1000
        return (thousands * 15)...(thousands * 20)
    }

    // MARK: - Hand test (palm over the coals)

    /// Maps "how many seconds can you hold your palm over the coals" to a
    /// temperature band — the campfire cook's calibration that needs no
    /// thermometer.
    ///
    /// - `>= 4s` → "325-350°F" (the steady baking band).
    /// - `>= 2s` → "375-425°F" (hot — searing / fast cooking).
    /// - `< 2s`  → "Too hot for most recipes" (pull coals).
    public static func handTestTemperatureF(seconds: Double) -> HandTestResult {
        if seconds >= 4 {
            return HandTestResult(label: "325-350°F")
        }
        if seconds >= 2 {
            return HandTestResult(label: "375-425°F")
        }
        return HandTestResult(label: "Too hot for most recipes")
    }

    // MARK: - Replenish cadence

    /// How often (minutes) to add fresh coals from the chimney. Coals burn
    /// down faster in the cold or the wind, so the cadence tightens:
    /// **30 minutes normally, 20 when it's cold OR windy.** (Both at once is
    /// still 20 — the loss isn't doubled, it's just "tend it sooner".)
    public static func replenishMinutes(ambient: AmbientCondition, windy: Bool) -> Int {
        let runsHot = ambient == .cold || windy
        return runsHot ? 20 : 30
    }
}

// MARK: - Value types

/// A recommended coal layout: how many on the `lid`, how many `bottom`, and
/// the `total`. Always `lid + bottom == total`.
public struct CoalSplit: Equatable, Sendable {
    public let lid: Int
    public let bottom: Int
    public let total: Int

    public init(lid: Int, bottom: Int, total: Int) {
        self.lid = lid
        self.bottom = bottom
        self.total = total
    }
}

/// How the cook wants the heat distributed. Drives the lid/bottom split in
/// ``DutchOvenHeatCoach/startingCoals(ovenDiameterInches:style:)``.
public enum CookingStyle: CaseIterable, Sendable, Hashable {
    /// Equal top and bottom — roasts, stews, one-pots.
    case even
    /// Lid-heavy 3:1 — breads, cobblers, cakes (brown the top, spare the
    /// bottom).
    case baking
}

/// The ambient air temperature bucket. Drives both the coal delta
/// (``DutchOvenHeatCoach/ambientCoalDelta(_:)``) and the replenish cadence
/// (``DutchOvenHeatCoach/replenishMinutes(ambient:windy:)``).
public enum AmbientCondition: CaseIterable, Sendable, Hashable {
    /// Roughly 90-100°F out — the oven holds heat, pull a couple of coals.
    case hot
    /// Comfortable — no adjustment.
    case mild
    /// Roughly 20-30°F out — the cold steals heat, add a couple of coals.
    case cold
}

/// The result of the palm-over-coals hand test — a small wrapper around the
/// temperature-band label so the call site renders one string and a future
/// revision can add fields (e.g. a numeric midpoint) without changing the
/// return shape.
public struct HandTestResult: Equatable, Sendable {
    /// Human-readable band, e.g. `"325-350°F"` or
    /// `"Too hot for most recipes"`.
    public let label: String

    public init(label: String) {
        self.label = label
    }
}
