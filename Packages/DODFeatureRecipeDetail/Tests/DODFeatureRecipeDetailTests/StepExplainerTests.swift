import DODFeatureRecipeDetail
import DODIntelligence
import Foundation
import Testing

@MainActor
struct StepExplainerTests {
    @Test
    func loadsCannedExplanation() async {
        let intelligence = FakeIntelligenceService(isAvailable: true)
        let stepExplainer = StepExplainer(intelligence: intelligence)

        await stepExplainer.explain(steps: ["a", "b"], index: 0)

        #expect(stepExplainer.state == .loaded(.canned))
    }

    @Test
    func unavailableServiceYieldsUnavailable() async {
        let intelligence = FakeIntelligenceService(isAvailable: false)
        let stepExplainer = StepExplainer(intelligence: intelligence)

        await stepExplainer.explain(steps: ["a", "b"], index: 0)

        #expect(stepExplainer.state == .unavailable)
        #expect(stepExplainer.isOffered == false)
    }

    @Test
    func nilServiceNotOffered() {
        let stepExplainer = StepExplainer(intelligence: nil)

        #expect(stepExplainer.isOffered == false)
    }

    @Test
    func outOfRangeIndexIsUnavailable() async {
        let intelligence = FakeIntelligenceService(isAvailable: true)
        let stepExplainer = StepExplainer(intelligence: intelligence)

        await stepExplainer.explain(steps: [], index: 0)

        #expect(stepExplainer.state == .unavailable)
    }

    @Test
    func resetReturnsToIdle() {
        let intelligence = FakeIntelligenceService(isAvailable: true)
        let stepExplainer = StepExplainer(intelligence: intelligence)

        stepExplainer.reset()

        #expect(stepExplainer.state == .idle)
    }
}
