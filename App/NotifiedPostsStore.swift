import Foundation

/// DUT-1397 — small, bounded set of post ids the user has already been told
/// about, shared by the remote-push path and the `BGAppRefreshTask` poller so a
/// post announced by one is never announced again by the other.
struct NotifiedPostsStore {

    static let key = "dod.notifications.notifiedPostIDs"
    /// Newest ids are kept; older ones fall off so the set cannot grow forever.
    static let capacity = 50

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var ids: [Int] { defaults.array(forKey: Self.key) as? [Int] ?? [] }

    func contains(_ id: Int) -> Bool { ids.contains(id) }

    func record(_ id: Int) {
        var current = ids.filter { $0 != id }
        current.append(id)
        defaults.set(Array(current.suffix(Self.capacity)), forKey: Self.key)
    }

    /// Ids from `candidates` that neither this store nor `alreadyDelivered`
    /// (notifications still sitting in Notification Center, e.g. a push shown
    /// while the app was not running) has announced. Order preserved.
    func unannounced(_ candidates: [Int], alreadyDelivered: Set<Int> = []) -> [Int] {
        let known = Set(ids).union(alreadyDelivered)
        return candidates.filter { !known.contains($0) }
    }
}
