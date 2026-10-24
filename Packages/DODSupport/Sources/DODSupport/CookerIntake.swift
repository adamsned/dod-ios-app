import Foundation

/// DUT-982 — the First-Cook Fit Quiz answers. Pure value model, no UI.
public struct CookerIntake: Codable, Equatable, Sendable {
    public enum Setup: String, Codable, Sendable, CaseIterable { case indoor, outdoor, both }
    public enum Experience: String, Codable, Sendable, CaseIterable { case none, some, lots }

    public var hasDutchOven: Bool
    /// Inches. nil when unknown or no oven.
    public var ovenSizeInches: Int?
    public var setup: Setup
    public var experience: Experience

    public init(hasDutchOven: Bool, ovenSizeInches: Int? = nil, setup: Setup, experience: Experience) {
        self.hasDutchOven = hasDutchOven
        self.ovenSizeInches = ovenSizeInches
        self.setup = setup
        self.experience = experience
    }

    /// True when the cook can safely be sent to a fire-based (charcoal/campfire) dish.
    public var hasOutdoorFire: Bool { setup == .outdoor || setup == .both }
}
