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
final class LiveConditionsFetcher: NSObject, ConditionsFetching, CLLocationManagerDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var manager: CLLocationManager?

    func fetchConditions() async throws -> HeatCoachConditions {
        let location = try await requestLocation()
        let weather = try await WeatherService.shared.weather(for: location, including: .current)
        let temperatureF = weather.temperature.converted(to: .fahrenheit).value
        let windMPH = max(weather.wind.speed, weather.wind.gust ?? weather.wind.speed)
            .converted(to: .milesPerHour).value
        return HeatCoachConditions.classify(
            temperatureF: temperatureF,
            windMPH: windMPH,
            altitudeMeters: location.altitude,
            fetchedAt: Date()
        )
    }

    @MainActor
    private func requestLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
            let manager = CLLocationManager()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyKilometer
            store(continuation: continuation, manager: manager)
            manager.requestWhenInUseAuthorization()
            manager.requestLocation()
        }
    }

    private func store(continuation: CheckedContinuation<CLLocation, Error>, manager: CLLocationManager) {
        lock.withLock {
            self.continuation = continuation
            self.manager = manager
        }
    }

    /// Takes the stored continuation so it can be resumed exactly once.
    private func takeContinuation() -> CheckedContinuation<CLLocation, Error>? {
        lock.withLock {
            let taken = continuation
            continuation = nil
            manager = nil
            return taken
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        takeContinuation()?.resume(returning: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        takeContinuation()?.resume(throwing: error)
    }
}
#endif
