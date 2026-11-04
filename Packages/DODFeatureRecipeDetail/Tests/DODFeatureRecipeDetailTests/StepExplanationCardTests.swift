import DODIntelligence
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
struct StepExplanationCardTests {
    @Test
    func idleBodyBuilds() {
        _ = StepExplanationCard(state: .idle, onTap: {}).body
    }

    @Test
    func loadingBodyBuilds() {
        _ = StepExplanationCard(state: .loading, onTap: {}).body
    }

    @Test
    func loadedBodyBuilds() {
        _ = StepExplanationCard(state: .loaded(.canned), onTap: {}).body
    }

    @Test
    func unavailableBodyBuilds() {
        _ = StepExplanationCard(state: .unavailable, onTap: {}).body
    }

    @Test
    func allStatesConstruct() {
        let states: [StepExplainer.State] = [.idle, .loading, .unavailable, .loaded(.canned)]
        for state in states {
            _ = StepExplanationCard(state: state, onTap: {})
        }
    }
}
