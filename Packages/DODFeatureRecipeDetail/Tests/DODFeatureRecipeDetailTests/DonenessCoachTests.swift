import DODFeatureRecipeDetail
import DODIntelligence
import Foundation
import Testing

@MainActor
struct DonenessCoachTests {
    @Test
    func unavailableServiceLeavesIdle() async {
        let coach = DonenessCoach(intelligence: FakeIntelligenceService(isAvailable: false))
        #expect(coach.isAvailable == false)
        await coach.check(photo: Data([1]), stepText: "Bake")
        #expect(coach.state == .idle)
    }

    @Test
    func nilServiceLeavesIdle() async {
        let coach = DonenessCoach(intelligence: nil)
        #expect(coach.isAvailable == false)
        await coach.check(photo: Data([1]), stepText: "Bake")
        #expect(coach.state == .idle)
    }
}
