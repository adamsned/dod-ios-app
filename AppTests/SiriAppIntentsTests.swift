import DODAnalytics
import DODDomain
import DODFeatureRecipeDetail
import Foundation
import XCTest

@testable import DODApp

/// DUT-1388 — the pure seams behind the Siri / Shortcuts intents: search
/// ranking, collection matching, dialog copy, the donation mapping, the
/// voice-command enum, and the onscreen-recipe fallback.
@MainActor
final class SiriAppIntentsTests: XCTestCase {

    private func payload(_ id: Int, _ title: String) -> RecipeEntityPayload {
        RecipeEntityPayload(id: id, title: title, excerpt: "", heroImage: nil, canonicalURL: nil)
    }

    // MARK: - Recipe search ranking

    func test_rank_keepsTitleMatchesOnly_strongestFirst() {
        let local = [payload(1, "Dutch Oven Chili Mac"), payload(2, "Peach Cobbler")]
        let remote = [payload(3, "Chili"), payload(4, "Best Dutch Ovens for Camping")]
        let ranked = RecipeEntityQuery.rank(local: local, remote: remote, query: "chili", limit: 10)
        // Exact "Chili" outranks the substring hit; cobbler + the article drop out.
        XCTAssertEqual(ranked.map(\.id), [3, 1])
    }

    func test_rank_localBeforeRemote_withinATier_andDedupesByID() {
        let local = [payload(1, "Chili Mac")]
        let remote = [payload(2, "White Chicken Chili"), payload(1, "Chili Mac")]
        let ranked = RecipeEntityQuery.rank(local: local, remote: remote, query: "chili", limit: 10)
        XCTAssertEqual(ranked.map(\.id), [1, 2])
    }

    func test_rank_respectsLimit_andEmptyQuery() {
        let remote = (1...20).map { payload($0, "Chili \($0)") }
        XCTAssertEqual(RecipeEntityQuery.rank(local: [], remote: remote, query: "chili", limit: 5).count, 5)
        XCTAssertTrue(RecipeEntityQuery.rank(local: [], remote: remote, query: "   ", limit: 5).isEmpty)
    }

    // MARK: - Collections

    private func collection(_ name: String, count: Int = 2) -> CollectionEntity {
        CollectionEntity(
            collection: RecipeCollection(
                id: UUID(),
                name: name,
                sortOrder: 0,
                createdAt: .distantPast,
                recipeIDs: Array(0..<count)
            )
        )
    }

    func test_collectionMatch_nameMatch_strongestFirst_shelfOrderOtherwise() {
        let pool = [collection("Weeknight Dinners"), collection("Desserts"), collection("Dinners")]
        let names = { (query: String) in CollectionEntityQuery.match(pool, query: query).map(\.name) }
        XCTAssertEqual(names("dinners"), ["Dinners", "Weeknight Dinners"])
        XCTAssertEqual(names("dessert"), ["Desserts"])  // singular
        XCTAssertTrue(names("").isEmpty)
    }

    func test_collectionCountText() {
        XCTAssertEqual(CollectionEntity.countText(1), "1 recipe")
        XCTAssertEqual(CollectionEntity.countText(0), "0 recipes")
        XCTAssertEqual(CollectionEntity.countText(7), "7 recipes")
    }

    // MARK: - Dialog copy (no em dashes in user-facing strings)

    func test_findDialog() {
        let text = FindRecipesIntent.dialogText
        XCTAssertEqual(text(0, "gnocchi"), "I couldn't find a recipe matching \"gnocchi\".")
        XCTAssertEqual(text(1, "gnocchi"), "Here's the recipe I found for \"gnocchi\".")
        XCTAssertEqual(text(4, "chili"), "Here are 4 recipes for \"chili\".")
    }

    func test_shoppingListDialog() {
        typealias Intent = AddRecipeToShoppingListIntent
        XCTAssertEqual(
            Intent.dialogText(.added(count: 1), title: "Chili"),
            "Added 1 ingredient from Chili to your Shopping List."
        )
        XCTAssertEqual(
            Intent.dialogText(.added(count: 9), title: "Chili"),
            "Added 9 ingredients from Chili to your Shopping List."
        )
        XCTAssertEqual(
            Intent.dialogText(.couldntLoad, title: "Chili"),
            "I couldn't load the ingredients for Chili. Open the recipe and try again."
        )
        for text in [Intent.dialogText(.couldntLoad, title: "X"), FindRecipesIntent.dialogText(count: 2, query: "x")] {
            XCTAssertFalse(text.contains("\u{2014}"))
        }
    }

    // MARK: - Donations

    func test_donationMapping() {
        XCTAssertEqual(IntentDonationTransport.donation(for: .recipeView(recipeID: 5))?.kind, .open)
        XCTAssertEqual(IntentDonationTransport.donation(for: .recipeView(recipeID: 5))?.recipeID, 5)
        XCTAssertEqual(IntentDonationTransport.donation(for: .cookModeStarted(recipeID: 9))?.kind, .cook)
        XCTAssertEqual(IntentDonationTransport.donation(for: .cookModeStarted(recipeID: 9))?.recipeID, 9)
        XCTAssertNil(IntentDonationTransport.donation(for: .recipeSaved(recipeID: 5)))
        XCTAssertNil(IntentDonationTransport.donation(for: .appOpen))
    }

    // MARK: - Voice commands (one App Shortcut, five commands)

    func test_cookModeCommandOption_mapsEveryCase() {
        XCTAssertEqual(CookModeCommandOption.next.voiceCommand, .next)
        XCTAssertEqual(CookModeCommandOption.previous.voiceCommand, .previous)
        XCTAssertEqual(CookModeCommandOption.repeat.voiceCommand, .repeat)
        XCTAssertEqual(CookModeCommandOption.pause.voiceCommand, .pause)
        XCTAssertEqual(CookModeCommandOption.resume.voiceCommand, .resume)
    }

    /// The case titles + synonyms ARE the Siri vocabulary carried over from the
    /// five retired App Shortcuts; pin them so a copy sweep can't drop one.
    func test_cookModeCommandOption_keepsTheOldPhrases() {
        let words = CookModeCommandOption.caseDisplayRepresentations.values.flatMap { rep in
            [String(localized: rep.title)] + rep.synonyms.map { String(localized: $0) }
        }
        for phrase in [
            "Next step", "Next", "Go forward", "Previous step", "Go back", "Back", "Repeat step",
            "Repeat that", "Say that again", "Pause reading", "Pause", "Resume reading", "Continue reading",
        ] {
            XCTAssertTrue(words.contains(phrase), phrase)
        }
    }

    // MARK: - Onscreen recipe ("this")

    func test_onscreenRecipe_showHide_onlyClearsTheSameRecipe() {
        let onscreen = OnscreenRecipe()
        onscreen.show(payload(1, "A"))
        onscreen.show(payload(2, "B"))  // pushed a related recipe
        onscreen.hide(id: 1)  // the covered one disappears: B stays
        XCTAssertEqual(onscreen.payload?.id, 2)
        onscreen.hide(id: 2)
        XCTAssertNil(onscreen.payload)
    }

    func test_resolve_prefersTheNamedRecipe() {
        let named = RecipeEntity(payload: payload(7, "Named"))
        XCTAssertEqual(OnscreenRecipe.resolve(named)?.id, 7)
    }
}
