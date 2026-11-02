import Foundation

/// DUT-135 — remembers the cook's last target internal temp (°F) per recipe,
/// plus built-in doneness presets used to seed the target.
public struct ProbeTargetStore: @unchecked Sendable {
    static let key = "dod.probe.targets"
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public static let presets: [(name: String, targetTemperature: Double)] = [
        ("Poultry", 165), ("Pork", 145), ("Beef medium-rare", 135),
        ("Beef medium", 145), ("Brisket", 203), ("Bread", 195),
    ]

    public func target(forRecipe id: Int) -> Double? {
        (defaults.dictionary(forKey: Self.key) as? [String: Double])?[String(id)]
    }

    public func setTarget(_ targetTemperature: Double, forRecipe id: Int) {
        var all = (defaults.dictionary(forKey: Self.key) as? [String: Double]) ?? [:]
        all[String(id)] = targetTemperature
        defaults.set(all, forKey: Self.key)
    }
}
