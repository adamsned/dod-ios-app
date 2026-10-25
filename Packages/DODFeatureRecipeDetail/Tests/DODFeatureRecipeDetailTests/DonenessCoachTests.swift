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

    @Test
    func resultSetsResultState() async {
        let expected = DonenessCheckResult(verdict: .looksDone, confidence: 0.9, reassurance: "Golden.")
        let coach = DonenessCoach(intelligence: FakeIntelligenceService(doneness: expected))
        #expect(coach.isAvailable)
        await coach.check(photo: Data([1]), stepText: "Bake until golden")
        #expect(coach.state == .result(expected))
    }

    @Test
    func nilResultSetsUnavailable() async {
        let coach = DonenessCoach(intelligence: FakeIntelligenceService(doneness: nil))
        await coach.check(photo: Data([1]), stepText: "Bake until golden")
        #expect(coach.state == .unavailable)
    }

    @Test
    func resetReturnsToIdle() async {
        let coach = DonenessCoach(intelligence: FakeIntelligenceService())
        await coach.check(photo: Data([1]), stepText: "Bake")
        #expect(coach.state != .idle)
        coach.reset()
        #expect(coach.state == .idle)
    }
}
