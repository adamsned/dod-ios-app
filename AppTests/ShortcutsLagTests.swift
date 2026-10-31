import DODDomain
import Foundation
import XCTest

@testable import DODApp

/// DUT-2255 — the rules that keep the Shortcuts app responsive: a short App
/// Shortcut suggestion list, and only telling iOS to re-expand shortcuts when
/// the suggestions or collections actually change.
@MainActor
final class ShortcutsLagTests: XCTestCase {

    private func payload(_ id: Int) -> RecipeEntityPayload {
        RecipeEntityPayload(id: id, title: "Recipe \(id)", excerpt: "", heroImage: nil, canonicalURL: nil)
    }

    // MARK: - Suggestion list

    func test_suggestions_recentsFirst_thenSaved_deduped() {
        let recents = [3, 1, 9].map(payload)
        let saved = [1, 2, 3, 4].map(payload)
        let ids = RecipeEntityQuery.shortcutSuggestions(saved: saved, recents: recents).map(\.id)
        XCTAssertEqual(ids, [3, 1, 9, 2, 4])
    }

    func test_suggestions_capAt15_andOnly5Recents() {
        let recents = (100..<110).map(payload)  // 10 recents, only 5 used
        let saved = (1...40).map(payload)
        let ids = RecipeEntityQuery.shortcutSuggestions(saved: saved, recents: recents).map(\.id)
        XCTAssertEqual(ids.count, 15)
        XCTAssertEqual(Array(ids.prefix(5)), [100, 101, 102, 103, 104])
        XCTAssertFalse(ids.contains(105))
        XCTAssertEqual(RecipeEntityQuery.shortcutSuggestionLimit, 15)
    }

    func test_suggestions_emptyWhenNothingSavedOrViewed() {
        XCTAssertTrue(RecipeEntityQuery.shortcutSuggestions(saved: [], recents: []).isEmpty)
    }

    // MARK: - Change signature (gates updateAppShortcutParameters)

    private func collection(_ id: UUID, _ name: String, count: Int) -> CollectionEntity {
        CollectionEntity(
            collection: RecipeCollection(
                id: id,
                name: name,
                sortOrder: 0,
                createdAt: .distantPast,
                recipeIDs: Array(0..<count)
            )
        )
    }

    func test_signature_stableWhenNothingChanged() {
        let id = UUID()
        let one = AppEntityIndex.signature(recipeIDs: [1, 2], collections: [collection(id, "Desserts", count: 3)])
        let two = AppEntityIndex.signature(recipeIDs: [1, 2], collections: [collection(id, "Desserts", count: 3)])
        XCTAssertEqual(one, two)
    }

    func test_signature_changesOnSuggestionOrCollectionChanges() {
        let id = UUID()
        func sig(_ ids: [Int], _ shelf: [CollectionEntity]) -> String {
            AppEntityIndex.signature(recipeIDs: ids, collections: shelf)
        }
        let base = sig([1, 2], [collection(id, "Desserts", count: 3)])
        XCTAssertNotEqual(base, sig([1, 2, 3], [collection(id, "Desserts", count: 3)]))  // new suggestion
        XCTAssertNotEqual(base, sig([1, 2], [collection(id, "Sweets", count: 3)]))  // renamed
        XCTAssertNotEqual(base, sig([1, 2], [collection(id, "Desserts", count: 4)]))  // recipe added
        XCTAssertNotEqual(base, sig([1, 2], []))  // deleted
    }

    // MARK: - Thumbnails

    /// A recipe with no cached hero never carries image bytes (so its tile uses
    /// the symbol instead of downloading the remote photo).
    func test_entityWithoutCachedHero_hasNoThumbnailBytes() {
        let entity = RecipeEntity(
            payload: RecipeEntityPayload(
                id: 1,
                title: "Chili",
                excerpt: "",
                heroImage: URL(string: "https://www.dutchovendaddy.com/hero.jpg"),
                canonicalURL: nil
            )
        )
        XCTAssertNil(entity.thumbnailData)
    }
}
