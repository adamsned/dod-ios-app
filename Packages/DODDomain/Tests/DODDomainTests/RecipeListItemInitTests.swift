import Foundation
import Testing

@testable import DODDomain

@Suite struct RecipeListItemInitTests {

    // MARK: Test 1 — Full RecipeListItem with all fields populated
    @Test func fullRecipeListItemPassesAllFieldsThrough() {
        let publishedDate = Date(timeIntervalSince1970: 1_234_567_890)
        let heroURL = URL(string: "https://example.com/image.jpg") ?? URL(filePath: "/")
        let canonicalURL = URL(string: "https://www.dutchovendaddy.com/recipe1") ?? URL(filePath: "/")
        let categoryIDs = [1, 2, 3]

        let listItem = RecipeListItem(
            id: 42,
            title: "Dutch Oven Braise",
            excerpt: "A delicious slow-cooked braise",
            heroImage: heroURL,
            publishedAt: publishedDate,
            totalTimeDisplay: "2 hours",
            canonicalURL: canonicalURL,
            categoryIDs: categoryIDs
        )

        let recipe = Recipe(listItem: listItem)

        // Verify passthrough of id, title, excerpt, heroImage, publishedAt
        #expect(recipe.id == listItem.id)
        #expect(recipe.title == listItem.title)
        #expect(recipe.excerpt == listItem.excerpt)
        #expect(recipe.heroImage == listItem.heroImage)
        #expect(recipe.publishedAt == listItem.publishedAt)

        // Verify passthrough of canonicalURL and categoryIDs
        #expect(recipe.canonicalURL == canonicalURL)
        #expect(recipe.categoryIDs == categoryIDs)

        // Verify slug is always empty
        #expect(recipe.slug.isEmpty)

        // Verify ingredients are always empty
        #expect(recipe.ingredients.isEmpty)
    }

    // MARK: Test 2 — canonicalURL nil → fallback to dutchovendaddy.com
    @Test func nilCanonicalURLUsesDidFallback() {
        let publishedDate = Date(timeIntervalSince1970: 1_234_567_890)
        let heroURL = URL(string: "https://example.com/image.jpg") ?? URL(filePath: "/")

        let listItem = RecipeListItem(
            id: 43,
            title: "Cast Iron Skillet Cornbread",
            excerpt: "Golden, buttery cornbread",
            heroImage: heroURL,
            publishedAt: publishedDate,
            canonicalURL: nil,
            categoryIDs: [5, 6]
        )

        let recipe = Recipe(listItem: listItem)

        // Verify the fallback URL is used
        let expectedFallback = URL(string: "https://www.dutchovendaddy.com/") ?? URL(filePath: "/")
        #expect(recipe.canonicalURL == expectedFallback)

        // Verify other fields are unaffected
        #expect(recipe.id == 43)
        #expect(recipe.title == "Cast Iron Skillet Cornbread")
        #expect(recipe.excerpt == "Golden, buttery cornbread")
        #expect(recipe.heroImage == heroURL)
        #expect(recipe.categoryIDs == [5, 6])
        #expect(recipe.slug.isEmpty)
        #expect(recipe.ingredients.isEmpty)
    }

    // MARK: Test 3 — categoryIDs nil → defaults to empty array
    @Test func nilCategoryIDsDefaultsToEmpty() {
        let publishedDate = Date(timeIntervalSince1970: 9_876_543_210)
        let canonicalURL = URL(string: "https://www.dutchovendaddy.com/recipe2") ?? URL(filePath: "/")

        let listItem = RecipeListItem(
            id: 44,
            title: "Sourdough Starter Guide",
            excerpt: "Building your starter from scratch",
            publishedAt: publishedDate,
            canonicalURL: canonicalURL,
            categoryIDs: nil
        )

        let recipe = Recipe(listItem: listItem)

        // Verify categoryIDs defaults to empty array
        #expect(recipe.categoryIDs.isEmpty)

        // Verify other fields are correct
        #expect(recipe.id == 44)
        #expect(recipe.title == "Sourdough Starter Guide")
        #expect(recipe.canonicalURL == canonicalURL)
        #expect(recipe.heroImage == nil)
        #expect(recipe.slug.isEmpty)
        #expect(recipe.ingredients.isEmpty)
    }

    // MARK: Test 4 — categoryIDs explicit empty array [] → stays empty
    @Test func explicitEmptyCategoryIDsStaysEmpty() {
        let publishedDate = Date(timeIntervalSince1970: 5_555_555_555)
        let canonicalURL = URL(string: "https://www.dutchovendaddy.com/recipe3") ?? URL(filePath: "/")

        let listItem = RecipeListItem(
            id: 45,
            title: "Seasoning Cast Iron",
            excerpt: "Keep your pan in pristine condition",
            publishedAt: publishedDate,
            canonicalURL: canonicalURL,
            categoryIDs: []
        )

        let recipe = Recipe(listItem: listItem)

        // Verify explicit empty array is preserved (not treated differently from nil)
        #expect(recipe.categoryIDs.isEmpty)

        // Verify other fields
        #expect(recipe.id == 45)
        #expect(recipe.slug.isEmpty)
        #expect(recipe.ingredients.isEmpty)
    }

    // MARK: Test 5 — heroImage nil → stays nil (no fallback for this field)
    @Test func nilHeroImageStaysNil() {
        let publishedDate = Date(timeIntervalSince1970: 7_777_777_777)
        let canonicalURL = URL(string: "https://www.dutchovendaddy.com/recipe4") ?? URL(filePath: "/")

        let listItem = RecipeListItem(
            id: 46,
            title: "No Image Recipe",
            excerpt: "Recipe without a hero image",
            heroImage: nil,
            publishedAt: publishedDate,
            canonicalURL: canonicalURL,
            categoryIDs: [10]
        )

        let recipe = Recipe(listItem: listItem)

        // Verify heroImage is nil (no fallback applied, unlike canonicalURL)
        #expect(recipe.heroImage == nil)

        // Verify other fields
        #expect(recipe.id == 46)
        #expect(recipe.title == "No Image Recipe")
        #expect(recipe.excerpt == "Recipe without a hero image")
        #expect(recipe.publishedAt == publishedDate)
        #expect(recipe.canonicalURL == canonicalURL)
        #expect(recipe.categoryIDs == [10])
        #expect(recipe.slug.isEmpty)
        #expect(recipe.ingredients.isEmpty)
    }
}
