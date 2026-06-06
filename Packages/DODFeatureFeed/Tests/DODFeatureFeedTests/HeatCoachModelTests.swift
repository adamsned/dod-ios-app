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

    @Test func windNote_onlyWhenWindy_andLeadsWithEnvironment() {
        #expect(model(windy: false).windNote == nil)
        let copy = model(windy: true).windNote
        #expect(copy?.contains("fix the environment first") == true)
        #expect(copy?.lowercased().contains("windbreak") == true)
    }

    // MARK: - Static config

    @Test func ovenSizes_areTheExpectedRange() {
        #expect(HeatCoachModel.ovenSizes == [8, 10, 12, 14, 16])
    }
}
