#if os(iOS) && canImport(UIKit)
import DODDomain
import Foundation
import Testing
import UIKit

@testable import DODFeatureRecipeDetail

/// L1 coverage for the print-ready recipe PDF (DUT-1324). The rendered *look*
/// needs the eye, but these lock the structural guarantees: valid PDF bytes,
/// content present, and correct pagination for a long recipe.
@Suite("RecipePDFRenderer")
struct RecipePDFRendererTests {

    private func recipe(ingredients: Int, steps: Int, title: String = "Test Recipe") -> Recipe {
        Recipe(
            id: 1,
            slug: "test-recipe",
            title: title,
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/1/") ?? URL(fileURLWithPath: "/"),
            heroImage: nil,
            heroImageLargeURL: nil,
            categoryIDs: [],
            publishedAt: Date(timeIntervalSince1970: 0),
            ingredients: (0..<ingredients).map {
                RecipeIngredient(id: UUID(), text: "Ingredient \($0)")
            },
            instructions: (0..<steps).map {
                RecipeInstruction(id: UUID(), step: $0 + 1, text: "Step \($0 + 1) text.")
            },
            prepTime: nil,
            cookTime: nil,
            totalTime: nil,
            servings: 4,
            nutrition: nil,
            video: nil,
            kind: .recipe,
            articleBodyHTML: nil,
            recipeCategory: [],
            recipeCuisine: [],
            suitableForDiet: [],
            author: nil
        )
    }

    private func pageCount(_ data: Data) -> Int {
        guard let provider = CGDataProvider(data: data as CFData),
            let doc = CGPDFDocument(provider)
        else { return 0 }
        return doc.numberOfPages
    }

    @Test func producesValidPDFBytes() {
        let data = RecipePDFRenderer().pdfData(
            recipe: recipe(ingredients: 5, steps: 4),
            heroImage: nil,
            logo: nil
        )
        #expect(!data.isEmpty)
        // Every PDF starts with the "%PDF" magic header.
        #expect(data.prefix(4) == Data("%PDF".utf8))
        #expect(pageCount(data) >= 1)
    }

    @Test func shortRecipeIsSinglePage() {
        let data = RecipePDFRenderer().pdfData(
            recipe: recipe(ingredients: 4, steps: 3),
            heroImage: nil,
            logo: nil
        )
        #expect(pageCount(data) == 1)
    }

    @Test func longRecipePaginates() {
        // Far more content than one US Letter page holds — must not clip.
        let data = RecipePDFRenderer().pdfData(
            recipe: recipe(ingredients: 40, steps: 40),
            heroImage: nil,
            logo: nil
        )
        #expect(pageCount(data) >= 2)
    }

    @Test func rendersWithHeroAndLogo() {
        // A 1×1 image stands in for the hero/logo — exercises the image-drawing
        // branches without a network fetch.
        let dot = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        let data = RecipePDFRenderer().pdfData(
            recipe: recipe(ingredients: 5, steps: 4),
            heroImage: dot,
            logo: dot
        )
        #expect(pageCount(data) >= 1)
    }
}
#endif
