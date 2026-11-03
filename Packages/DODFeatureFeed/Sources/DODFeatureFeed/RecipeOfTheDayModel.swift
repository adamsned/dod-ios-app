import DODAnalytics
import DODDomain
import Foundation
import Observation

/// DUT-117 — resolves and holds the Recipe of the Day shown at the top of the feed.
/// The pick is persisted per calendar day, so it is stable all day even as the
/// feed pages, refreshes, or loads from the offline cache. nil item = hide the card.
@Observable
@MainActor
public final class RecipeOfTheDayModel {
    public private(set) var item: RecipeListItem?

    private let store: RecipeOfTheDayStore
    private let now: () -> Date
    private let send: (AnalyticsEvent) -> Void
    private var impressionDayKey: String?

    init(
        store: RecipeOfTheDayStore,
        now: @escaping () -> Date,
        send: @escaping (AnalyticsEvent) -> Void
    ) {
        self.store = store
        self.now = now
        self.send = send
    }

    public convenience init() {
        self.init(store: RecipeOfTheDayStore(), now: Date.init, send: { Telemetry.shared.send($0) })
    }

    private var todayKey: String { RecipeOfTheDayStore.dayKey(for: now()) }

    /// Resolve today's recipe. `pool` is the feed's loaded (or cache-hydrated) items;
    /// `lookup` fetches already-picked ids that aren't in `pool` (e.g. from the list cache).
    public func resolve(
        pool: [RecipeListItem],
        lookup: ([Int]) async -> [RecipeListItem]
    ) async {
        let key = todayKey
        if let id = store.pickedID(forDayKey: key) {
            if let hit = pool.first(where: { $0.id == id }) {
                item = hit
            } else if let hit = await lookup([id]).first {
                item = hit
            }
            return  // a pick already exists for today: never re-pick
        }
        guard let pick = RecipeOfTheDayPicker.pick(from: pool, dayKey: key, excluding: store.recentIDs()) else {
            item = nil
            return
        }
        store.record(id: pick.id, dayKey: key)
        item = pick
    }

    /// Sends `recipeOfTheDayShown` at most once per calendar day per model instance.
    public func recordImpressionIfNeeded() {
        let key = todayKey
        guard let item, impressionDayKey != key else { return }
        impressionDayKey = key
        send(.recipeOfTheDayShown(recipeID: item.id))
    }
}
