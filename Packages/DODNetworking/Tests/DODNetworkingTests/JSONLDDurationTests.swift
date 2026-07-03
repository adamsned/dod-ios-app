import Foundation
import Testing

@testable import DODNetworking

/// DUT-356 — `parseISO8601Duration` must accept an optional date portion before
/// the "T" (e.g. `P0DT8H` for an 8-hour cook), not just bare `PT…`, so long
/// Dutch-oven cook times don't vanish. Malformed input is rejected, not
/// silently truncated.
@Suite("JSONLDRecipeParser.parseISO8601Duration (DUT-356)") struct JSONLDDurationTests {

    @Test func parsesTimeOnlyDurations() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT1H30M") == .seconds(5400))
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT45M") == .seconds(2700))
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT90S") == .seconds(90))
    }

    @Test func parsesDateComponentDurations() {
        #expect(JSONLDRecipeParser.parseISO8601Duration("P0DT8H") == .seconds(28800))
        #expect(JSONLDRecipeParser.parseISO8601Duration("P0DT45M") == .seconds(2700))
        #expect(JSONLDRecipeParser.parseISO8601Duration("P1DT2H") == .seconds(93600))
    }

    @Test func rejectsMalformedOrUnsupported() {
        // Trailing digits with no unit — malformed, don't silently drop them.
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT1H30") == nil)
        // "M" in the date part = months, which recipes don't use.
        #expect(JSONLDRecipeParser.parseISO8601Duration("P1M") == nil)
        #expect(JSONLDRecipeParser.parseISO8601Duration("garbage") == nil)
        #expect(JSONLDRecipeParser.parseISO8601Duration(nil) == nil)
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT0S") == nil)  // zero → nil
    }

    /// DUT-518 — a giant digit run in untrusted scraped JSON-LD overflows the
    /// `Int64` accumulator. Under trapping `*`/`+` that crashed; now it must
    /// return nil (treated as "no duration") without trapping.
    @Test func rejectsOverflowingDurationsWithoutCrashing() {
        // Digit run itself exceeds Int64.max (`Int64(buffer)` fails first).
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT99999999999999999999H") == nil)
        // Value fits Int64 but `value * multiplier` overflows.
        #expect(JSONLDRecipeParser.parseISO8601Duration("PT9999999999999999H") == nil)
        #expect(JSONLDRecipeParser.parseISO8601Duration("P9999999999999999D") == nil)
        // Each part + its product fit, but the running sum overflows.
        #expect(JSONLDRecipeParser.parseISO8601Duration("P100000000000000DT200000000000000H") == nil)
    }
}
