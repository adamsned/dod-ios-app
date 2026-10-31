import DODSupport
import Foundation

/// DUT-998 — abstract source of live conditions; the real one needs GPS + network.
protocol ConditionsFetching: Sendable {
    func fetchConditions() async throws -> HeatCoachConditions
}

/// Fetch fresh conditions and cache them; on failure fall back to the cached copy (offline-safe).
struct ConditionsProvider: Sendable {
    let fetcher: any ConditionsFetching
    let store: HeatCoachConditionsStore

    /// Returns (conditions, isFresh). nil only when the fetch failed AND nothing is cached.
    func refresh() async -> (conditions: HeatCoachConditions, isFresh: Bool)? {
        if let fresh = try? await fetcher.fetchConditions() {
            store.save(fresh)
            return (fresh, true)
        }
        if let cached = store.load() { return (cached, false) }
        return nil
    }
}

#if canImport(WeatherKit) && canImport(CoreLocation) && os(iOS)
import CoreLocation
import WeatherKit

/// Real fetcher. Altitude comes from GPS (works with no cell signal); temp/wind from one WeatherKit call.
final class LiveConditionsFetcher: NSObject, ConditionsFetching, @unchecked Sendable {
    func fetchConditions() async throws -> HeatCoachConditions { throw CancellationError() }
}
#endif
