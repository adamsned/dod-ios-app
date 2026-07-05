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

    @Test func adjustedCoalSplit_cold_addsCoals() {
        // base 24 (12" even) + midpoint of cold delta (2...3 → 3) = 27
        #expect(model(ambient: .cold).adjustedCoalSplit.total == 27)
    }

    @Test func adjustedCoalSplit_hot_pullsCoals() {
        // base 24 + midpoint of hot delta (-3...-2 → -3) = 21
        #expect(model(ambient: .hot).adjustedCoalSplit.total == 21)
    }

    @Test func adjustedCoalSplit_coldAndWindy_stacksBothDeltas() {
        // cold (2...3) + wind (3...4) = 5...7 → midpoint 6 → 24 + 6 = 30
        #expect(model(ambient: .cold, windy: true).adjustedCoalSplit.total == 30)
    }

    @Test func adjustedCoalSplit_reSplitsByStyle() {
        // baking, cold: total 27 re-split 3:1 → lid 20, bottom 7
        let split = model(style: .baking, ambient: .cold).adjustedCoalSplit
        #expect(split.total == 27)
        #expect(split.lid == 20)
        #expect(split.bottom == 7)
    }

    @Test func adjustedCoalSplit_elevationDoesNotChangeCoals() {
        // elevation adjusts cook TIME, not coal count — total stays the base 24
        #expect(model(elevationFeet: 5000, ambient: .mild).adjustedCoalSplit.total == 24)
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
