import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

@Suite struct ConditionsProviderTests {
    private struct StubFetcher: ConditionsFetching {
        let result: HeatCoachConditions?
        func fetchConditions() async throws -> HeatCoachConditions {
            guard let result else { throw CancellationError() }
            return result
        }
    }

    private func makeStore() -> HeatCoachConditionsStore {
        let defaults = UserDefaults(suiteName: UUID().uuidString) ?? UserDefaults.standard
        return HeatCoachConditionsStore(defaults: defaults)
    }

    private let sample = HeatCoachConditions(
        elevationFeet: 5000,
        ambient: .cold,
        windy: true,
        fetchedAt: Date(timeIntervalSince1970: 1_000_000)
    )

    @Test func freshFetchIsReturnedAndCached() async {
        let store = makeStore()
        let provider = ConditionsProvider(fetcher: StubFetcher(result: sample), store: store)
        let outcome = await provider.refresh()
        #expect(outcome?.conditions == sample)
        #expect(outcome?.isFresh == true)
        #expect(store.load() == sample)
    }

    @Test func failedFetchFallsBackToCache() async {
        let store = makeStore()
        store.save(sample)
        let provider = ConditionsProvider(fetcher: StubFetcher(result: nil), store: store)
        let outcome = await provider.refresh()
        #expect(outcome?.conditions == sample)
        #expect(outcome?.isFresh == false)
    }

    @Test func failedFetchWithEmptyCacheIsNil() async {
        let provider = ConditionsProvider(fetcher: StubFetcher(result: nil), store: makeStore())
        let outcome = await provider.refresh()
        #expect(outcome == nil)
    }
}
