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
}
