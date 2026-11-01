import DODDomain
import Foundation
import Testing

@testable import DODSupport

@Suite("StagedIngredientsNote") struct StagedIngredientsNoteTests {
    private func recipe(steps: [String], ingredients: [String]) -> Recipe {
        Recipe(
            id: 1,
            slug: "s",
            title: "T",
            excerpt: "",
            canonicalURL: URL(fileURLWithPath: "/x"),
            publishedAt: Date(),
            ingredients: ingredients.map { RecipeIngredient(text: $0) },
            instructions: steps.enumerated().map { RecipeInstruction(step: $0.offset + 1, text: $0.element) }
        )
    }

    @Test func brownedBeefGoesInCooler() {
        let note = StagedIngredientsNote.build(
            from: recipe(steps: ["Brown the beef at home"], ingredients: ["2 lbs ground beef"])
        )
        #expect(note.cooler == ["2 lbs ground beef"])
        #expect(note.preppedDry.isEmpty)
        #expect(note.raw.isEmpty)
    }

    @Test func choppedOnionIsPreppedDry() {
        let note = StagedIngredientsNote.build(
            from: recipe(steps: ["Dice the onion"], ingredients: ["2 cups onion"])
        )
        #expect(note.preppedDry == ["2 cups onion"])
        #expect(note.cooler.isEmpty)
    }

    @Test func unmentionedIngredientTravelsRaw() {
        let note = StagedIngredientsNote.build(
            from: recipe(steps: ["Dice the onion"], ingredients: ["2 cups onion", "lasagna noodles"])
        )
        #expect(note.raw == ["lasagna noodles"])
    }

    @Test func noHomeStepsMeansAllRaw() {
        let note = StagedIngredientsNote.build(
            from: recipe(
                steps: ["Place coals on lid", "Serve hot"],
                ingredients: ["2 lbs ground beef", "2 cups onion"]
            )
        )
        #expect(note.raw == ["2 lbs ground beef", "2 cups onion"])
        #expect(note.cooler.isEmpty)
        #expect(note.preppedDry.isEmpty)
    }
}
