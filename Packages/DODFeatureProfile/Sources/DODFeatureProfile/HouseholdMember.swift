import Foundation

/// DUT-993: dietary / allergy flag a household member can carry.
public enum DietaryFlag: String, Codable, CaseIterable, Sendable, Hashable {
    case dairy, gluten, nuts, peanuts, eggs, shellfish, fish, soy, pork, vegetarian, vegan

    public var displayName: String {
        switch self {
        case .dairy: "dairy"
        case .gluten: "gluten"
        case .nuts: "tree nuts"
        case .peanuts: "peanuts"
        case .eggs: "eggs"
        case .shellfish: "shellfish"
        case .fish: "fish"
        case .soy: "soy"
        case .pork: "pork"
        case .vegetarian: "meat"
        case .vegan: "animal products"
        }
    }
}

/// DUT-993: coarse age band, drives the portion check (ticket 5).
public enum AgeBand: String, Codable, CaseIterable, Sendable, Hashable {
    case littleKid, kid, teenOrAdult
}

public struct HouseholdMember: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var ageBand: AgeBand?
    public var flags: Set<DietaryFlag>

    public init(id: UUID = UUID(), name: String, ageBand: AgeBand? = nil, flags: Set<DietaryFlag> = []) {
        self.id = id
        self.name = name
        self.ageBand = ageBand
        self.flags = flags
    }
}
