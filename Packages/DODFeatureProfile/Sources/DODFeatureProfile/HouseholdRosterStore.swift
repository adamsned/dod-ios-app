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

public struct UserDefaultsHouseholdRosterStore: HouseholdRosterStoring, @unchecked Sendable {
    public static let key = "com.dutchovendaddy.DODApp.householdRoster.v1"
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func load() async -> [HouseholdMember] {
        guard let data = defaults.data(forKey: Self.key),
            let members = try? JSONDecoder().decode([HouseholdMember].self, from: data)
        else { return [] }
        return members
    }
    public func save(_ members: [HouseholdMember]) async {
        guard let data = try? JSONEncoder().encode(members) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
