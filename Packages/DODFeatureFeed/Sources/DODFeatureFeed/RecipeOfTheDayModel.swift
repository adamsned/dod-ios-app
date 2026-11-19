import DODAnalytics
import DODDomain
import Foundation
import Observation

/// DUT-117 — resolves and holds the Recipe of the Day shown at the top of the feed.
/// The pick is persisted per calendar day, so it is stable all day even as the
/// feed pages, refreshes, or loads from the offline cache. nil item = hide the card.
///
/// DUT-2894 — the pick can be an article (a roundup like "27 Easy Campfire
/// Meals"). ``isArticle`` says which, so the card reads "Article of the Day".
/// It's classified once per day (the same JSON-LD check the Latest widget uses)
/// and stored with the pick, and ``item`` is only published once the kind is
/// known, so the label never flips from Recipe to Article on screen.
@Observable
@MainActor
public final class RecipeOfTheDayModel {
    public private(set) var item: RecipeListItem?
    /// DUT-2894 — true when today's pick is an article.
    public private(set) var isArticle = false

    private let store: RecipeOfTheDayStore
    private let now: () -> Date
    private let send: (AnalyticsEvent) -> Void
    /// DUT-2894 — recipe-vs-article check; nil (previews / tests) means "recipe".
    private let classifier: LiveFeedDependencies.LatestKindClassifier?
    private var impressionDayKey: String?

    init(
        store: RecipeOfTheDayStore,
        now: @escaping () -> Date,
        send: @escaping (AnalyticsEvent) -> Void,
        classifier: LiveFeedDependencies.LatestKindClassifier? = nil
    ) {
        self.store = store
        self.now = now
        self.send = send
        self.classifier = classifier
    }

    /// - Parameter classifier: DUT-2894 — the App's JSON-LD article classifier
    ///   (`AppDependencies.makeLatestKindClassifier()`); nil labels every pick
    ///   a recipe, the old behavior.
    public convenience init(classifier: LiveFeedDependencies.LatestKindClassifier? = nil) {
        self.init(
            store: RecipeOfTheDayStore(),
            now: Date.init,
            send: { Telemetry.shared.send($0) },
            classifier: classifier
        )
    }

    /// DUT-2894 — publish `pick` with its kind: the stored call for today, else
    /// classify now (once) and store it.
    private func publish(_ pick: RecipeListItem, dayKey: String) async {
        let kind: Bool
        if let stored = store.isArticle(forDayKey: dayKey) {
            kind = stored
        } else if let classifier {
            kind = await classifier(pick)
            store.recordKind(isArticle: kind, dayKey: dayKey)
        } else {
            kind = false
        }
        isArticle = kind
        item = pick
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
                await publish(hit, dayKey: key)
            } else if let hit = await lookup([id]).first {
                await publish(hit, dayKey: key)
            }
            return  // a pick already exists for today: never re-pick
        }
        guard let pick = RecipeOfTheDayPicker.pick(from: pool, dayKey: key, excluding: store.recentIDs()) else {
            item = nil
            isArticle = false
            return
        }
        store.record(id: pick.id, dayKey: key)
        await publish(pick, dayKey: key)
    }

    /// Sends `recipeOfTheDayShown` at most once per calendar day per model instance.
    public func recordImpressionIfNeeded() {
        let key = todayKey
        guard let item, impressionDayKey != key else { return }
        impressionDayKey = key
        send(.recipeOfTheDayShown(recipeID: item.id))
    }

    public func recordTap() {
        guard let item else { return }
        send(.recipeOfTheDayTapped(recipeID: item.id))
    }
}
