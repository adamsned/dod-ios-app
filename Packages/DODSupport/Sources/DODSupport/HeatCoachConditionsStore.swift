import Foundation

/// DUT-998 — remembers the last fetched conditions so Heat Coach stays usable with zero signal.
public struct HeatCoachConditionsStore: @unchecked Sendable {
    static let key = "dod.heatCoach.conditions"
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> HeatCoachConditions? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(HeatCoachConditions.self, from: data)
    }

    public func save(_ conditions: HeatCoachConditions) {
        guard let data = try? JSONEncoder().encode(conditions) else { return }
        defaults.set(data, forKey: Self.key)
    }

    public func clear() { defaults.removeObject(forKey: Self.key) }
}
