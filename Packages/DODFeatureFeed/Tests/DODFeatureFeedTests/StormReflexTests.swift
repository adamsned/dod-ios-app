import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// DUT-998 — Storm Reflex mid-cook nudge copy.
@Suite("StormReflex") struct StormReflexTests {

    private func model(ambient: AmbientCondition = .mild, windy: Bool = false) -> HeatCoachModel {
        HeatCoachModel(
            ovenDiameterInches: 12,
            style: .even,
            elevationFeet: 0,
            ambient: ambient,
            windy: windy
        )
    }

    @Test func windKickedUp_onCalmMild_addsFour() {
        let text = StormReflex.nudge(for: .windKickedUp, model: model())
        #expect(text == "Conditions changed: add 4 coals to hold your heat.")
    }

    @Test func windDied_onWindy_pullsFour() throws {
        let text = try #require(StormReflex.nudge(for: .windDied, model: model(windy: true)))
        #expect(text.contains("pull 4 coals"))
    }

    @Test func backToMild_onMildCalm_isNil() {
        #expect(StormReflex.nudge(for: .backToMild, model: model()) == nil)
    }

    @Test func gotCold_onMild_addsTwo() throws {
        let text = try #require(StormReflex.nudge(for: .gotCold, model: model()))
        #expect(text.contains("add 2 coals"))
    }
}
