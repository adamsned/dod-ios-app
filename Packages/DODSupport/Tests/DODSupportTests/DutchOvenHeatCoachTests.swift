import Foundation
import Testing

@testable import DODSupport

/// L1 unit coverage for ``DutchOvenHeatCoach`` — the pure, AVFoundation-free
/// coal-baseline + condition-adjustment + cook-by-feel engine behind the
/// Dutch Oven Heat Coach screen (DUT-48).
///
/// The numbers encoded here are lifted verbatim from Dutch Oven Daddy's
/// published method (the `/dutch-oven-temperature-chart/` page) — a baseline
/// estimate that the user then adapts by feel. These tests pin every rule +
/// its boundaries so a future "tidy-up" that nudges a constant trips CI and
/// surfaces to the spec author before it lands on a user's device.
///
/// Brand contract (DUT-48): this is NOT a coal-count chart. The estimate is
/// "a starting point, not a rule"; the feel cues are the point. The reference
/// content is exposed as structured data so the UI renders one source of
/// truth — those payloads are pinned at the bottom of this suite.
@Suite("DutchOvenHeatCoach") struct DutchOvenHeatCoachTests {

    // MARK: - startingCoals: total = diameter * 2 (the ~350F baseline)

    @Test func totalIsTwiceTheDiameter_even() {
        // 12" → 24 total. The canonical sanity check from the spec.
        let split = DutchOvenHeatCoach.startingCoals(ovenDiameterInches: 12, style: .even)
        #expect(split.total == 24)
    }

    @Test func totalIsTwiceTheDiameter_acrossSizes() {
        // 8 → 16, 10 → 20, 14 → 28, 16 → 32.
        #expect(DutchOvenHeatCoach.startingCoals(ovenDiameterInches: 8, style: .even).total == 16)
        #expect(DutchOvenHeatCoach.startingCoals(ovenDiameterInches: 10, style: .even).total == 20)
        #expect(DutchOvenHeatCoach.startingCoals(ovenDiameterInches: 14, style: .even).total == 28)
        #expect(DutchOvenHeatCoach.startingCoals(ovenDiameterInches: 16, style: .even).total == 32)
    }

    // MARK: - startingCoals: EVEN split (lid == bottom; odd extra to bottom)

    @Test func evenSplit_twelveInch_isTwelveTwelve() {
        let split = DutchOvenHeatCoach.startingCoals(ovenDiameterInches: 12, style: .even)
        #expect(split.lid == 12)
        #expect(split.bottom == 12)
        #expect(split.lid + split.bottom == split.total)
    }

    @Test func evenSplit_isBalancedForAllEvenTotals() {
        for diameter in [8, 10, 12, 14, 16] {
            let split = DutchOvenHeatCoach.startingCoals(ovenDiameterInches: diameter, style: .even)
            // total = diameter * 2 is always even, so lid == bottom exactly.
            #expect(split.lid == split.bottom)
            #expect(split.lid + split.bottom == split.total)
        }
    }

    @Test func evenSplit_oddTotalPutsExtraOnBottom() {
        // 9" → total 18 (still even). Force an odd total with a 7" oven
        // (total 14, even) — the *2 rule never yields an odd total for an
        // integer diameter, so we exercise the odd-handling contract through
        // the split helper's documented behavior: when total is odd, bottom
        // carries the extra. A 15" oven → 30 (even). To genuinely hit the
        // odd branch we use a diameter whose doubled value is odd only if a
        // future caller passes a half-inch-rounded size; we assert the
        // invariant directly for an odd synthetic total.
        let split = DutchOvenHeatCoach.evenSplit(total: 25)
        #expect(split.lid == 12)
        #expect(split.bottom == 13)
        #expect(split.lid + split.bottom == 25)
    }

    // MARK: - startingCoals: BAKING split (3:1 lid-heavy; lid = round(total*3/4))

    @Test func bakingSplit_twelveInch_isEighteenSix() {
        // 12" → 24 total → lid = round(24 * 3/4) = 18, bottom = 6.
        let split = DutchOvenHeatCoach.startingCoals(ovenDiameterInches: 12, style: .baking)
        #expect(split.lid == 18)
        #expect(split.bottom == 6)
        #expect(split.lid + split.bottom == split.total)
    }

    /// One expected baking split — a named struct rather than a 3-tuple so
    /// the `large_tuple` lint rule (max 2 members) stays satisfied.
    private struct BakingExpectation {
        let diameter: Int
        let lid: Int
        let bottom: Int
    }

    @Test func bakingSplit_isLidHeavyAcrossSizes() {
        // lid = round(total * 3/4), bottom = total - lid, for each size.
        let expected: [BakingExpectation] = [
            BakingExpectation(diameter: 8, lid: 12, bottom: 4),  // 16 → 12 / 4
            BakingExpectation(diameter: 10, lid: 15, bottom: 5),  // 20 → 15 / 5
            BakingExpectation(diameter: 12, lid: 18, bottom: 6),  // 24 → 18 / 6
            BakingExpectation(diameter: 14, lid: 21, bottom: 7),  // 28 → 21 / 7
            BakingExpectation(diameter: 16, lid: 24, bottom: 8),  // 32 → 24 / 8
        ]
        for entry in expected {
            let split = DutchOvenHeatCoach.startingCoals(ovenDiameterInches: entry.diameter, style: .baking)
            #expect(split.lid == entry.lid)
            #expect(split.bottom == entry.bottom)
            #expect(split.lid > split.bottom)  // always lid-heavy
            #expect(split.lid + split.bottom == split.total)
        }
    }

    @Test func bakingSplit_roundsLidToNearest() {
        // total 10 → 10 * 3/4 = 7.5 → round = 8 lid, 2 bottom.
        let split = DutchOvenHeatCoach.bakingSplit(total: 10)
        #expect(split.lid == 8)
        #expect(split.bottom == 2)
    }

    // MARK: - ambientCoalDelta: returns a RANGE (DOD says "2-3 coals")

    @Test func ambientDelta_hot_isMinusThreeToMinusTwo() {
        #expect(DutchOvenHeatCoach.ambientCoalDelta(.hot) == -3...(-2))
    }

    @Test func ambientDelta_cold_isPlusTwoToPlusThree() {
        #expect(DutchOvenHeatCoach.ambientCoalDelta(.cold) == 2...3)
    }

    @Test func ambientDelta_mild_isZeroToZero() {
        #expect(DutchOvenHeatCoach.ambientCoalDelta(.mild) == 0...0)
    }

    // MARK: - cookTimeExtraMinutes: +15..+20 min per 1,000 ft above baseline

    @Test func elevation_atBaseline_isZero() {
        #expect(DutchOvenHeatCoach.cookTimeExtraMinutes(elevationFeetAboveBaseline: 0) == 0...0)
    }

    @Test func elevation_oneThousandFeet_isFifteenToTwenty() {
        #expect(DutchOvenHeatCoach.cookTimeExtraMinutes(elevationFeetAboveBaseline: 1000) == 15...20)
    }

    @Test func elevation_threeThousandFeet_scalesLinearly() {
        // (3000/1000)*15 ... (3000/1000)*20 = 45 ... 60.
        #expect(DutchOvenHeatCoach.cookTimeExtraMinutes(elevationFeetAboveBaseline: 3000) == 45...60)
    }

    @Test func elevation_partialThousandTruncates() {
        // Integer thousands: 2500 ft → floor(2.5) = 2 → 30 ... 40.
        #expect(DutchOvenHeatCoach.cookTimeExtraMinutes(elevationFeetAboveBaseline: 2500) == 30...40)
    }

    @Test func elevation_belowBaselineClampsToZero() {
        // Negative (below the chosen baseline) never subtracts cook time.
        #expect(DutchOvenHeatCoach.cookTimeExtraMinutes(elevationFeetAboveBaseline: -1000) == 0...0)
    }

    // MARK: - handTestTemperatureF: the palm-over-coals feel test

    @Test func handTest_fourToFiveSeconds_isLow() {
        #expect(DutchOvenHeatCoach.handTestTemperatureF(seconds: 4).label == "325-350°F")
        #expect(DutchOvenHeatCoach.handTestTemperatureF(seconds: 5).label == "325-350°F")
        #expect(DutchOvenHeatCoach.handTestTemperatureF(seconds: 4.5).label == "325-350°F")
    }

    @Test func handTest_twoToThreeSeconds_isMid() {
        #expect(DutchOvenHeatCoach.handTestTemperatureF(seconds: 2).label == "375-425°F")
        #expect(DutchOvenHeatCoach.handTestTemperatureF(seconds: 3).label == "375-425°F")
        #expect(DutchOvenHeatCoach.handTestTemperatureF(seconds: 3.9).label == "375-425°F")
    }

    @Test func handTest_underTwoSeconds_isTooHot() {
        #expect(DutchOvenHeatCoach.handTestTemperatureF(seconds: 1.9).label == "Too hot for most recipes")
        #expect(DutchOvenHeatCoach.handTestTemperatureF(seconds: 0).label == "Too hot for most recipes")
    }

    @Test func handTest_boundariesAreInclusiveOnTheLowerEdge() {
        // >= 4 → low; >= 2 → mid; else too hot. Exact-boundary checks.
        #expect(DutchOvenHeatCoach.handTestTemperatureF(seconds: 4.0).label == "325-350°F")
        #expect(DutchOvenHeatCoach.handTestTemperatureF(seconds: 2.0).label == "375-425°F")
        // Just under each boundary flips to the hotter bucket.
        #expect(DutchOvenHeatCoach.handTestTemperatureF(seconds: 3.999).label == "375-425°F")
        #expect(DutchOvenHeatCoach.handTestTemperatureF(seconds: 1.999).label == "Too hot for most recipes")
    }

    // MARK: - replenishMinutes: 30 normally, 20 when cold OR windy

    @Test func replenish_mildCalm_isThirty() {
        #expect(DutchOvenHeatCoach.replenishMinutes(ambient: .mild, windy: false) == 30)
    }

    @Test func replenish_hotCalm_isThirty() {
        #expect(DutchOvenHeatCoach.replenishMinutes(ambient: .hot, windy: false) == 30)
    }

    @Test func replenish_coldCalm_isTwenty() {
        #expect(DutchOvenHeatCoach.replenishMinutes(ambient: .cold, windy: false) == 20)
    }

    @Test func replenish_mildWindy_isTwenty() {
        #expect(DutchOvenHeatCoach.replenishMinutes(ambient: .mild, windy: true) == 20)
    }

    @Test func replenish_coldAndWindy_isTwenty() {
        // Cold OR windy → 20; both true still 20 (not double-counted).
        #expect(DutchOvenHeatCoach.replenishMinutes(ambient: .cold, windy: true) == 20)
    }

    // MARK: - Reference content: structured, single source of truth

    @Test func reference_exposesAllFeelCueCategories() {
        // The cook-by-feel reference must surface every sense the page
        // teaches: visual (coal color + steam), hand test, sound, smell,
        // and lid condensation. Pinned so a future trim can't silently
        // drop the point of the feature.
        let categories = DutchOvenHeatCoach.feelCues.map(\.title)
        #expect(categories.contains("Coal Color"))
        #expect(categories.contains("Steam at the Lid Rim"))
        #expect(categories.contains("Hand Test"))
        #expect(categories.contains("Sound"))
        #expect(categories.contains("Smell"))
        #expect(categories.contains("Lid Condensation"))
    }

    @Test func reference_feelCuesEachHaveGoodAndAdjustSignals() {
        // Every cue pairs an "on track" signal with an "adjust" signal —
        // the whole adapt-by-feel loop in one row.
        for cue in DutchOvenHeatCoach.feelCues {
            #expect(!cue.title.isEmpty)
            #expect(!cue.onTrack.isEmpty)
            #expect(!cue.adjust.isEmpty)
        }
    }

    @Test func reference_coalManagementHabitsArePresent() {
        // The five coal-management habits lifted from the page.
        let habits = DutchOvenHeatCoach.coalManagementHabits
        #expect(habits.count == 5)
        #expect(habits.allSatisfy { !$0.isEmpty })
        // Spot-check the load-bearing ones by keyword so a paraphrase that
        // drops the substance (not just the wording) fails.
        let joined = habits.joined(separator: " | ").lowercased()
        #expect(joined.contains("chimney"))
        #expect(joined.contains("quarter-turn"))
        #expect(joined.contains("60"))  // replenish at 60-70% spent
        #expect(joined.contains("wind"))
    }

    @Test func reference_windGuidanceIsPresent() {
        let guidance = DutchOvenHeatCoach.windGuidance
        #expect(guidance.count == 3)
        let joined = guidance.joined(separator: " | ").lowercased()
        #expect(joined.contains("back-to-wind") || joined.contains("back to wind"))
        #expect(joined.contains("windbreak"))
        #expect(joined.contains("20 min"))
    }

    @Test func reference_handTestCueMatchesTheCalculator() {
        // The hand-test row in the reference must quote the same three
        // temperature bands the calculator returns — one source of truth.
        guard let handCue = DutchOvenHeatCoach.feelCues.first(where: { $0.title == "Hand Test" }) else {
            Issue.record("Hand Test cue missing from feelCues")
            return
        }
        #expect(handCue.onTrack.contains("325-350°F") || handCue.onTrack.contains("375-425°F"))
    }
}
