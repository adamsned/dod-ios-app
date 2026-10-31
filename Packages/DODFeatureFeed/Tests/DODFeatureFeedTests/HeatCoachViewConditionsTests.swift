import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

@Suite("HeatCoachView conditions") struct HeatCoachViewConditionsTests {
    @Test func cachedConditionsApplyOnlyToDefaults() {
        #expect(HeatCoachView.shouldApplyCached(elevationFeet: 0, ambient: .mild, windy: false))
        #expect(!HeatCoachView.shouldApplyCached(elevationFeet: 500, ambient: .mild, windy: false))
        #expect(!HeatCoachView.shouldApplyCached(elevationFeet: 0, ambient: .cold, windy: false))
        #expect(!HeatCoachView.shouldApplyCached(elevationFeet: 0, ambient: .mild, windy: true))
    }

    @Test func fetchedConditionsFeedTheCoalMath() {
        let conditions = HeatCoachConditions(
            elevationFeet: 5000,
            ambient: .cold,
            windy: true,
            fetchedAt: Date(timeIntervalSince1970: 0)
        )
        let model = HeatCoachModel(ovenDiameterInches: 12, style: .even, conditions: conditions)
        #expect(model.conditionCoalDelta == 7...9)
    }
}
