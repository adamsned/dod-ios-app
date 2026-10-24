import Foundation

/// DUT-993: load / save the household roster. Non-secret, so the production
/// impl uses UserDefaults rather than the Keychain.
public protocol HouseholdRosterStoring: Sendable {
    func load() async -> [HouseholdMember]
    func save(_ members: [HouseholdMember]) async
}

public actor InMemoryHouseholdRosterStore: HouseholdRosterStoring {
    private var stored: [HouseholdMember]
    public init(initial: [HouseholdMember] = []) { stored = initial }
    public func load() -> [HouseholdMember] { stored }
    public func save(_ members: [HouseholdMember]) { stored = members }
}
