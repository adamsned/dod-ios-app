import DODDomain
import Foundation
import Testing

@testable import DODFeatureFeed

/// Counts classifier calls (the classifier is `@Sendable`).
final class ClassifierCallBox: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var calls: Int { lock.withLock { count } }
    func bump() { lock.withLock { count += 1 } }
}

/// DUT-2894 — the Recipe of the Day banner reads "Article of the Day" for an
/// article pick, classified once per day and stored with the pick.
@MainActor
@Suite("Article of the Day (DUT-2894)")
struct ArticleOfTheDayTests {

    private func model(
        defaults: UserDefaults,
        calls: ClassifierCallBox,
        isArticle: Bool
    ) -> RecipeOfTheDayModel {
        RecipeOfTheDayModel(
            store: RecipeOfTheDayStore(defaults: defaults),
            now: { Date(timeIntervalSince1970: 1_800_000_000) },
            send: { _ in },
            classifier: { _ in
                calls.bump()
                return isArticle
            }
        )
    }

    @Test func articlePickIsLabeledAnArticle() async {
        let calls = ClassifierCallBox()
        let model = model(defaults: RecipeOfTheDayModelTests.freshDefaults(), calls: calls, isArticle: true)
        await model.resolve(pool: RecipeOfTheDayModelTests.items(1...5), lookup: { _ in [] })
        #expect(model.item != nil)
        #expect(model.isArticle)
    }

    @Test func recipePickStaysARecipe() async {
        let calls = ClassifierCallBox()
        let model = model(defaults: RecipeOfTheDayModelTests.freshDefaults(), calls: calls, isArticle: false)
        await model.resolve(pool: RecipeOfTheDayModelTests.items(1...5), lookup: { _ in [] })
        #expect(!model.isArticle)
    }

    /// Classified once per day: a later resolve (or a relaunch) reuses the stored
    /// call, so the label can't flip and the page isn't re-fetched.
    @Test func kindIsClassifiedOncePerDayAndStored() async {
        let defaults = RecipeOfTheDayModelTests.freshDefaults()
        let calls = ClassifierCallBox()
        let first = model(defaults: defaults, calls: calls, isArticle: true)
        await first.resolve(pool: RecipeOfTheDayModelTests.items(1...5), lookup: { _ in [] })
        await first.resolve(pool: RecipeOfTheDayModelTests.items(1...5), lookup: { _ in [] })
        let relaunch = model(defaults: defaults, calls: calls, isArticle: false)  // would say recipe
        await relaunch.resolve(pool: RecipeOfTheDayModelTests.items(1...5), lookup: { _ in [] })
        #expect(calls.calls == 1)
        #expect(relaunch.isArticle)
    }

    @Test func noClassifierMeansRecipe() async {
        let model = RecipeOfTheDayModelTests.makeModel(defaults: RecipeOfTheDayModelTests.freshDefaults())
        await model.resolve(pool: RecipeOfTheDayModelTests.items(1...5), lookup: { _ in [] })
        #expect(!model.isArticle)
    }

    @Test func cardLabel() {
        #expect(RecipeOfTheDayCard.label(isArticle: true) == "Article of the Day")
        #expect(RecipeOfTheDayCard.label(isArticle: false) == "Recipe of the Day")
    }
}
