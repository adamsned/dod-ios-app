import DODDomain
import Foundation
import Testing

@testable import DODSupport

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
}
