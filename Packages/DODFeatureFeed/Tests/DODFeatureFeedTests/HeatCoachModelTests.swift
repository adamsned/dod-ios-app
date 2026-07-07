import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 coverage for ``HeatCoachModel`` — the pure math-to-copy mapping behind
/// the Dutch Oven Heat Coach screen (DUT-48). Exercised on the macOS slice so
/// the displayed strings are pinned without a snapshot host.
///
/// Spec trace: DUT-48 (result card headline + condition-adjustment copy +
/// the "starting point, not a rule" framing).
@Suite("HeatCoachModel") struct HeatCoachModelTests {

    private func model(
        diameter: Int = 12,
        style: CookingStyle = .even,
        elevationFeet: Int = 0,
        ambient: AmbientCondition = .mild,
        windy: Bool = false
    ) -> HeatCoachModel {
        HeatCoachModel(
            ovenDiameterInches: diameter,
            style: style,
            elevationFeet: elevationFeet,
            ambient: ambient,
            windy: windy
        )
    }

    // MARK: - Result headline

    @Test func headline_even12_readsTwelveTwelve() {
        let copy = model(diameter: 12, style: .even).coalHeadline
        #expect(copy == "Start with ~24 coals: 12 on the lid, 12 underneath")
    }

    @Test func headline_baking12_readsEighteenSix() {
        let copy = model(diameter: 12, style: .baking).coalHeadline
        #expect(copy == "Start with ~24 coals: 18 on the lid, 6 underneath")
    }

    @Test func styleNote_distinguishesEvenFromBaking() {
        #expect(model(style: .even).styleNote.contains("Even heat"))
        #expect(model(style: .baking).styleNote.contains("3:1"))
    }

    // MARK: - Condition-adjusted starting split (DUT-600)

    @Test func adjustedCoalSplit_mildCalm_equalsBase() {
        let mildCalm = model(ambient: .mild, windy: false)
        #expect(mildCalm.adjustedCoalSplit == mildCalm.coalSplit)
        #expect(mildCalm.conditionCoalDelta == 0...0)
    }

    // MARK: - Elevation moves the COAL count, not just cook time (DUT-682)

    @Test func adjustedCoalSplit_movesWithElevation() {
        // The bug: elevation used to leave the coal count unchanged. Now +1 per
        // 2,500 ft (5,000 ft → +2 → 24 + 2 = 26), so the diagram MOVES.
        let seaLevel = model(elevationFeet: 0)
        let highAltitude = model(elevationFeet: 5000)
        #expect(seaLevel.adjustedCoalSplit.total == 24)
        #expect(highAltitude.adjustedCoalSplit.total == 26)
        #expect(highAltitude.adjustedCoalSplit.total != seaLevel.adjustedCoalSplit.total)
    }

    @Test func conditionCoalDelta_includesElevation() {
        // mild + calm + 5,000 ft → 0 + 0 + 2 = 2...2.
        #expect(model(elevationFeet: 5000).conditionCoalDelta == 2...2)
        // Stacks with ambient + wind: cold (2...3) + wind (3...4) + elevation (2) = 7...9.
        #expect(model(elevationFeet: 5000, ambient: .cold, windy: true).conditionCoalDelta == 7...9)
    }

    @Test func adjustedCoalSplit_elevationStacksWithConditions() {
        // 7...9 → midpoint 8 → 24 + 8 = 32.
        #expect(model(elevationFeet: 5000, ambient: .cold, windy: true).adjustedCoalSplit.total == 32)
    }

    @Test func elevationCoalNote_reflectsTheDelta() {
        #expect(model(elevationFeet: 0).elevationCoalNote == nil)
        #expect(model(elevationFeet: 2000).elevationCoalNote == nil)  // below the 2,500-ft first step
        #expect(model(elevationFeet: 2500).elevationCoalNote?.contains("add 1 coal,") == true)
        let high = model(elevationFeet: 5000).elevationCoalNote
        #expect(high?.contains("add 2 coals") == true)
        #expect(high?.contains("5,000") == true)
    }

    @Test func adjustedCoalSplit_cold_addsCoals() {
        // DUT-653: base 24 (12" even) + midpoint of cold delta (2...3 → 2.5,
        // rounded to-nearest-even → 2) = 26. The old away-from-zero rounding
        // biased this to 3 (→ 27).
        #expect(model(ambient: .cold).adjustedCoalSplit.total == 26)
    }

    @Test func adjustedCoalSplit_hot_pullsCoals() {
        // DUT-653: base 24 + midpoint of hot delta (-3...-2 → -2.5, rounded
        // to-nearest-even → -2) = 22. The old rounding biased this to -3 (→ 21).
        #expect(model(ambient: .hot).adjustedCoalSplit.total == 22)
    }

    @Test func adjustedCoalSplit_coldAndWindy_stacksBothDeltas() {
        // cold (2...3) + wind (3...4) = 5...7 → midpoint 6 → 24 + 6 = 30
        #expect(model(ambient: .cold, windy: true).adjustedCoalSplit.total == 30)
    }

    @Test func adjustedCoalSplit_reSplitsByStyle() {
        // DUT-653: baking, cold: total 26 (midpoint 2, nearest-even) re-split
        // 3:1 → lid round(26 * 0.75) = round(19.5) = 20, bottom 6.
        let split = model(style: .baking, ambient: .cold).adjustedCoalSplit
        #expect(split.total == 26)
        #expect(split.lid == 20)
        #expect(split.bottom == 6)
    }

    @Test func adjustedCoalSplit_elevationAddsCoals() {
        // DUT-682: elevation now adjusts BOTH cook time AND the coal count.
        // 5,000 ft → +2 coals (1 per 2,500 ft) → base 24 → 26.
        #expect(model(elevationFeet: 5000, ambient: .mild).adjustedCoalSplit.total == 26)
    }

    // MARK: - Ambient note (mild omitted; hot/cold show a range)

    @Test func ambientNote_mild_isOmitted() {
        #expect(model(ambient: .mild).ambientNote == nil)
    }

    @Test func ambientNote_cold_addsTwoToThree() {
        let copy = model(ambient: .cold).ambientNote
        #expect(copy?.contains("add 2-3 coals") == true)
    }

    @Test func ambientNote_hot_pullsTwoToThree() {
        // The delta is negative (-3...-2) but the copy renders the magnitude
        // as "2-3" and supplies "pull".
        let copy = model(ambient: .hot).ambientNote
        #expect(copy?.contains("pull 2-3 coals") == true)
    }

    // MARK: - Elevation note (baseline omitted; scales)

    @Test func elevationNote_atBaseline_isOmitted() {
        #expect(model(elevationFeet: 0).elevationNote == nil)
    }

    @Test func elevationNote_threeThousand_addsFortyFiveToSixty() {
        let copy = model(elevationFeet: 3000).elevationNote
        #expect(copy?.contains("add 45-60 minutes") == true)
        // Thousands separator renders for readability.
        #expect(copy?.contains("3,000 ft") == true)
    }

    // MARK: - Elevation cook-time line (always shown; DUT-601)

    @Test func elevationCookTimeLine_atBaseline_statesUsualTime() {
        #expect(model(elevationFeet: 0).elevationCookTimeLine == "Cook for the recipe's usual time.")
    }

    @Test func elevationCookTimeLine_threeThousand_addsTime() {
        let copy = model(elevationFeet: 3000).elevationCookTimeLine
        #expect(copy.contains("45–60 min"))
        #expect(copy.contains("3,000 ft"))
    }

    // MARK: - Replenish + wind

    @Test func replenishNote_mildCalm_isThirty() {
        #expect(model(ambient: .mild, windy: false).replenishNote.contains("every 30 minutes"))
    }

    @Test func replenishNote_windy_isTwentyWithReason() {
        let copy = model(ambient: .mild, windy: true).replenishNote
        #expect(copy.contains("every 20 minutes"))
        #expect(copy.contains("burn down faster"))
    }

    @Test func windNote_onlyWhenWindy_isTheEnvironmentTip() {
        #expect(model(windy: false).windNote == nil)
        let copy = model(windy: true).windNote
        #expect(copy?.contains("fix the environment") == true)
        #expect(copy?.lowercased().contains("windbreak") == true)
    }

    /// DUT-264 — wind adjusts the coal COUNT (add 3-4), not just the cadence.
    @Test func windCoalNote_onlyWhenWindy_addsThreeToFour() {
        #expect(model(windy: false).windCoalNote == nil)
        let copy = model(windy: true).windCoalNote
        #expect(copy?.contains("add 3-4 coals") == true)
        #expect(copy?.lowercased().contains("steals heat") == true)
    }

    // MARK: - Static config

    @Test func ovenSizes_areTheExpectedRange() {
        #expect(HeatCoachModel.ovenSizes == [8, 10, 12, 14, 16])
    }
}
