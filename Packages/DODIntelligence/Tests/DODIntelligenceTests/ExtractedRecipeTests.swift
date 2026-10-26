import Testing
import XCTest

@testable import DODIntelligence

@Suite
struct ExtractedRecipeTests {

    @Test
    func chunksOfEmptyString() {
        #expect(RecipeTextChunker.chunks(of: "").isEmpty)
    }

    @Test
    func chunksOfSingleLine() {
        let text = String(repeating: "a", count: 9000)
        let chunks = RecipeTextChunker.chunks(of: text, maxCharacters: 4000)
        #expect(chunks.count == 3)
        for chunk in chunks {
            #expect(chunk.count <= 4000)
        }
    }

    @Test
    func chunksOfThreeParagraphs() {
        let para1 = String(repeating: "a", count: 1500)
        let para2 = String(repeating: "b", count: 1500)
        let para3 = String(repeating: "c", count: 1500)
        let text = "\(para1)\n\n\(para2)\n\n\(para3)"
        let chunks = RecipeTextChunker.chunks(of: text, maxCharacters: 4000)
        #expect(chunks.count == 2)
    }

    @Test
    func merged() {
        let recipe1 = ExtractedRecipe(
            ingredients: ["flour", "sugar", "salt"],
            instructions: ["mix", "bake", "cool"]
        )
        let recipe2 = ExtractedRecipe(
            ingredients: ["flour", "eggs", "milk"],  // duplicate "flour" should be removed
            instructions: ["mix", "fry", "serve"]  // duplicate "mix" should be removed
        )
        let merged = ExtractedRecipe.merged([recipe1, recipe2])

        #expect(merged.ingredients == ["flour", "sugar", "salt", "eggs", "milk"])
        #expect(merged.instructions == ["mix", "bake", "cool", "fry", "serve"])
    }
}
