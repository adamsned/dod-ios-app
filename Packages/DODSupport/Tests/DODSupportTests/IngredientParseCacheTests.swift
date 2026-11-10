import DODDomain
import Foundation
import Testing

@testable import DODSupport

actor Counter {
    private(set) var count = 0
    func increment() { count += 1 }
}

@Suite struct IngredientParseCacheTests {
    @Test func storeThenCachedReturnsValueAndNilIsDistinctFromMiss() async {
        let cache = IngredientParseCache()
        let ing = RecipeIngredient(text: "2 cups flour")
        let miss = await cache.cached(for: ing.id)
        #expect(miss == nil)  // outer nil = never stored
        await cache.store(nil, for: ing.id)
        let declined = await cache.cached(for: ing.id)
        #expect(declined != nil)  // outer .some(nil) = model declined
        let parse = IngredientParse(quantity: 2, unit: "cups", item: "flour", prep: nil)
        await cache.store(parse, for: ing.id)
        let hit = await cache.cached(for: ing.id)
        #expect(hit == .some(.some(parse)))
    }

    @Test func removeAllClearsEntries() async {
        let cache = IngredientParseCache()
        let ing = RecipeIngredient(text: "2 cups flour")
        await cache.store(nil, for: ing.id)
        await cache.removeAll()
        let after = await cache.cached(for: ing.id)
        #expect(after == nil)
    }

    @Test func sameIngredientParsedOnce() async {
        let cache = IngredientParseCache()
        let counter = Counter()
        let ing = RecipeIngredient(text: "2 cups flour")
        let parser: @Sendable (String) async -> IngredientParse? = { _ in
            await counter.increment()
            return IngredientParse(quantity: 2, unit: "cups", item: "flour", prep: nil)
        }
        let first = await cache.parse(ing, using: parser)
        let second = await cache.parse(ing, using: parser)
        #expect(first == second)
        #expect(await counter.count == 1)
    }

    @Test func nilResultIsCached() async {
        let cache = IngredientParseCache()
        let counter = Counter()
        let ing = RecipeIngredient(text: "2 cups flour")
        let parser: @Sendable (String) async -> IngredientParse? = { _ in
            await counter.increment()
            return nil
        }
        _ = await cache.parse(ing, using: parser)
        let again = await cache.parse(ing, using: parser)
        #expect(again == nil)
        #expect(await counter.count == 1)
    }

    @Test func differentIngredientsEachParseOnce() async {
        let cache = IngredientParseCache()
        let counter = Counter()
        let parser: @Sendable (String) async -> IngredientParse? = { text in
            await counter.increment()
            return IngredientParse(quantity: nil, unit: nil, item: text, prep: nil)
        }
        let flour = RecipeIngredient(text: "2 cups flour")
        let salt = RecipeIngredient(text: "1 tsp salt")
        _ = await cache.parse(flour, using: parser)
        _ = await cache.parse(salt, using: parser)
        _ = await cache.parse(flour, using: parser)
        _ = await cache.parse(salt, using: parser)
        #expect(await counter.count == 2)
    }

    @Test func removeAllForcesReparse() async {
        let cache = IngredientParseCache()
        let counter = Counter()
        let ing = RecipeIngredient(text: "2 cups flour")
        let parser: @Sendable (String) async -> IngredientParse? = { _ in
            await counter.increment()
            return nil
        }
        _ = await cache.parse(ing, using: parser)
        await cache.removeAll()
        _ = await cache.parse(ing, using: parser)
        #expect(await counter.count == 2)
    }
}
