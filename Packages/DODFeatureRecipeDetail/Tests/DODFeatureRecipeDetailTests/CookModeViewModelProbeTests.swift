import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("Cook Mode probe session (DUT-135)") struct CookModeViewModelProbeTests {

    private func makeStore() -> ProbeTargetStore {
        let name = "probe-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return ProbeTargetStore(defaults: defaults)
    }

    @Test func seedUsesDefaultWhenNothingStored() {
        let session = ProbeSession()
        session.seedTarget(recipeID: 1, defaultF: 165, store: makeStore())
        #expect(session.targetF == 165)
    }

    @Test func storedTargetBeatsDefault() {
        let store = makeStore()
        store.setTarget(150, forRecipe: 1)
        let session = ProbeSession()
        session.seedTarget(recipeID: 1, defaultF: 165, store: store)
        #expect(session.targetF == 150)
    }

    @Test func nearThenReachedBanners() {
        let session = ProbeSession()
        session.setTarget(165, recipeID: 1, store: makeStore())
        var alerts: [ProbeAlert] = []
        session.onAlert = { alerts.append($0) }
        session.ingest(ProbeReading(internalF: 156))
        #expect(session.bannerText?.contains("Almost") == true)
        session.ingestManual(166)
        #expect(session.bannerText?.contains("Target reached") == true)
        #expect(alerts == [.nearTarget, .targetReached])
    }
}
