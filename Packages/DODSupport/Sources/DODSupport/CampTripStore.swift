import Foundation

/// DUT-1000 — local-only persistence for the in-progress camp trip and its fuel ledger.
///
/// `@unchecked Sendable` matches ``PanCareStore``: the only stored property is a
/// `let UserDefaults`, which Apple documents as thread-safe.
public struct CampTripStore: @unchecked Sendable {
    static let key = "dod.campTrip.current"
    private let defaults: UserDefaults

    /// Test seam — inject a throwaway `UserDefaults(suiteName:)`.
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public struct Snapshot: Codable, Sendable, Equatable {
        public var trip: CampTrip
        public var ledger: CampFuelLedger
        public init(trip: CampTrip, ledger: CampFuelLedger) {
            self.trip = trip
            self.ledger = ledger
        }
    }

    public func load() -> Snapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    public func save(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
    }

    public func clear() { defaults.removeObject(forKey: Self.key) }
}
