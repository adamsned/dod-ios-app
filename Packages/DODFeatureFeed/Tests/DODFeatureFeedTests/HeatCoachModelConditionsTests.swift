import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// DUT-998 — conditions-based init and the Storm Reflex coal-total change.
@Suite("HeatCoachModel conditions") struct HeatCoachModelConditionsTests {

    private func model(ambient: AmbientCondition = .mild, windy: Bool = false) -> HeatCoachModel {
        HeatCoachModel(
            ovenDiameterInches: 12,
            style: .even,
            elevationFeet: 0,
            ambient: ambient,
            windy: windy
        )
    }

    @Test func initFromConditions_mapsEveryField() {
        let conditions = HeatCoachConditions(
            elevationFeet: 5000,
            ambient: .cold,
            windy: true,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        let built = HeatCoachModel(ovenDiameterInches: 12, style: .even, conditions: conditions)
        #expect(built.elevationFeet == 5000)
        #expect(built.ambient == .cold)
        #expect(built.windy)
        #expect(built.conditionCoalDelta == 7...9)
        #expect(built.adjustedCoalSplit.total == 32)
    }

    @Test func coalTotalChange_calmToWindy_isPlusFour() {
        // wind 3...4 midpoint 3.5 rounds to even 4: 24 -> 28.
        #expect(model().coalTotalChange(newAmbient: .mild, newWindy: true) == 4)
    }

    @Test func coalTotalChange_windyToCalm_isMinusFour() {
        #expect(model(windy: true).coalTotalChange(newAmbient: .mild, newWindy: false) == -4)
    }

    @Test func coalTotalChange_unchanged_isZero() {
        #expect(model().coalTotalChange(newAmbient: .mild, newWindy: false) == 0)
        #expect(model(ambient: .cold, windy: true).coalTotalChange(newAmbient: .cold, newWindy: true) == 0)
    }
}
