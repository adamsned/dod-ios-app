import Foundation

/// DUT-965 — persists the single active `CookoutPlan`.
public struct CookoutPlanStore: @unchecked Sendable {
    public static let key = "dod.cookout.activePlan.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func save(_ plan: CookoutPlan) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(plan) else { return }
        defaults.set(data, forKey: Self.key)
    }

    public func load() -> CookoutPlan? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(CookoutPlan.self, from: data)
    }

    public func clear() { defaults.removeObject(forKey: Self.key) }
}
