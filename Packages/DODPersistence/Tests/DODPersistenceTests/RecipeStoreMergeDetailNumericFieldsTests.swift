import DODDomain
import Foundation
import Testing

@testable import DODPersistence

// MARK: - Numeric field preservation (DUT-399)

@Suite("RecipeStore mergeDetail numeric field preservation (DUT-399)")
struct RecipeStoreMergeDetailNumericFieldsTests {

    @Test func nutritionEncodedWhenPresentPreservedWhenNil() async throws {
        let store = try await makeStore()
        let nutrition = RecipeNutrition(
            calories: "250",
            servingSize: "1 slice",
            proteinGrams: "12",
            carbsGrams: "45",
            fatGrams: "8"
        )
        try await store.mergeDetail(
            makeRecipe(id: 101, nutrition: nutrition)
        )

        let first = try #require(try await store.recipe(id: 101))
        #expect(
            first.nutrition?.calories == "250",
            "First merge must encode nutrition"
        )

        try await store.mergeDetail(makeRecipe(id: 101, nutrition: nil))
        let second = try #require(try await store.recipe(id: 101))
        #expect(
            second.nutrition?.calories == "250",
            "Nil nutrition must preserve cached (DUT-399)"
        )
    }

    @Test func videoEncodedWhenPresentPreservedWhenNil() async throws {
        let store = try await makeStore()
        let video = RecipeVideo(
            url: URL(string: "https://example.com/video.mp4")
                ?? URL(filePath: "/"),
            duration: .seconds(120)
        )
        try await store.mergeDetail(makeRecipe(id: 102, video: video))

        let first = try #require(try await store.recipe(id: 102))
        #expect(
            first.video?.url.absoluteString.contains("video.mp4") ?? false,
            "First merge must encode video"
        )

        try await store.mergeDetail(makeRecipe(id: 102, video: nil))
        let second = try #require(try await store.recipe(id: 102))
        #expect(
            second.video?.url.absoluteString.contains("video.mp4") ?? false,
            "Nil video must preserve cached (DUT-399)"
        )
    }

    @Test func timesConvertedToSecondsPreservedWhenNil() async throws {
        let store = try await makeStore()
        try await store.mergeDetail(
            makeRecipe(
                id: 103,
                prepTime: .seconds(15 * 60),
                cookTime: .seconds(45 * 60),
                totalTime: .seconds(60 * 60)
            )
        )

        let first = try #require(try await store.recipe(id: 103))
        #expect(first.prepTime == .seconds(15 * 60))
        #expect(first.cookTime == .seconds(45 * 60))
        #expect(first.totalTime == .seconds(60 * 60))

        try await store.mergeDetail(
            makeRecipe(
                id: 103,
                prepTime: nil,
                cookTime: nil,
                totalTime: nil
            )
        )
        let second = try #require(try await store.recipe(id: 103))
        #expect(
            second.prepTime == .seconds(15 * 60),
            "Nil prep time must preserve (DUT-399)"
        )
        #expect(
            second.cookTime == .seconds(45 * 60),
            "Nil cook time must preserve (DUT-399)"
        )
        #expect(
            second.totalTime == .seconds(60 * 60),
            "Nil total time must preserve (DUT-399)"
        )
    }

    @Test func servingsUpdatesWhenPresentPreservedWhenNil() async throws {
        let store = try await makeStore()
        try await store.mergeDetail(makeRecipe(id: 104, servings: 4))

        let first = try #require(try await store.recipe(id: 104))
        #expect(first.servings == 4)

        try await store.mergeDetail(makeRecipe(id: 104, servings: nil))
        let second = try #require(try await store.recipe(id: 104))
        #expect(
            second.servings == 4,
            "Nil servings must preserve cached (DUT-399)"
        )
    }

    @Test func fieldIndependence_firstMergeCapturesAllFields() async throws {
        let store = try await makeStore()
        let nutrition = RecipeNutrition(calories: "300", carbsGrams: "50")
        let video = RecipeVideo(
            url: URL(string: "https://example.com/cake.mp4")
                ?? URL(filePath: "/"),
            duration: .seconds(90)
        )

        try await store.mergeDetail(
            makeRecipe(
                id: 105,
                nutrition: nutrition,
                video: video,
                prepTime: .seconds(20 * 60),
                servings: 6
            )
        )
        let first = try #require(try await store.recipe(id: 105))
        #expect(first.nutrition?.calories == "300")
        #expect(first.video?.duration == .seconds(90))
        #expect(first.prepTime == .seconds(20 * 60))
        #expect(first.servings == 6)
    }

    @Test func fieldIndependence_secondMergePreservesUntouchedFields() async throws {
        let store = try await makeStore()
        let nutrition = RecipeNutrition(calories: "300", carbsGrams: "50")
        let video = RecipeVideo(
            url: URL(string: "https://example.com/cake.mp4")
                ?? URL(filePath: "/"),
            duration: .seconds(90)
        )
        try await store.mergeDetail(
            makeRecipe(
                id: 105,
                nutrition: nutrition,
                video: video,
                prepTime: .seconds(20 * 60),
                servings: 6
            )
        )

        try await store.mergeDetail(
            makeRecipe(
                id: 105,
                cookTime: .seconds(50 * 60),
                servings: nil
            )
        )
        let second = try #require(try await store.recipe(id: 105))
        #expect(
            second.nutrition?.calories == "300",
            "Nil nutrition must preserve despite update"
        )
        #expect(
            second.video?.duration == .seconds(90),
            "Nil video must preserve despite update"
        )
        #expect(
            second.cookTime == .seconds(50 * 60),
            "Cook time must update independently"
        )
        #expect(
            second.prepTime == .seconds(20 * 60),
            "Prep time must remain unchanged"
        )
        #expect(
            second.servings == 6,
            "Nil servings must preserve despite update"
        )
    }

    @Test func numericFieldsOverwriteWhenPresent() async throws {
        let store = try await makeStore()
        try await store.mergeDetail(
            makeRecipe(
                id: 106,
                prepTime: .seconds(10 * 60),
                servings: 4
            )
        )

        let first = try #require(try await store.recipe(id: 106))
        #expect(first.servings == 4)
        #expect(first.prepTime == .seconds(10 * 60))

        try await store.mergeDetail(
            makeRecipe(
                id: 106,
                prepTime: .seconds(30 * 60),
                servings: 8
            )
        )
        let second = try #require(try await store.recipe(id: 106))
        #expect(second.servings == 8, "Servings must update")
        #expect(second.prepTime == .seconds(30 * 60), "Prep time must update")
    }
}

// MARK: - Numeric field helper

private func makeRecipe(
    id: Int,
    nutrition: RecipeNutrition? = nil,
    video: RecipeVideo? = nil,
    prepTime: Duration? = nil,
    cookTime: Duration? = nil,
    totalTime: Duration? = nil,
    servings: Int? = nil
) -> Recipe {
    Recipe(
        id: id,
        slug: "slug-\(id)",
        title: "Title \(id)",
        excerpt: "Excerpt.",
        canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/")
            ?? URL(filePath: "/"),
        publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
        ingredients: [],
        instructions: [],
        prepTime: prepTime,
        cookTime: cookTime,
        totalTime: totalTime,
        servings: servings,
        nutrition: nutrition,
        video: video
    )
}
