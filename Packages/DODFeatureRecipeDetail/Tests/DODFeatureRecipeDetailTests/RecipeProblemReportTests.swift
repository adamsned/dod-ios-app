import Testing

@testable import DODFeatureRecipeDetail

@Suite struct RecipeProblemReportTests {
    @Test func mailtoTargetsTheTeamWithRecipeAndType() {
        let report = RecipeProblemReport(recipeID: 42, recipeTitle: "Pot Roast", problemType: .ingredient, note: "")
        guard let url = report.mailtoURL else {
            #expect(Bool(false), "mailtoURL should not be nil")
            return
        }
        #expect(url.scheme == "mailto")
        #expect(url.absoluteString.hasPrefix("mailto:ned@dutchovendaddy.com"))
        #expect(report.body.contains("Recipe ID: 42"))
        #expect(report.body.contains("Pot Roast"))
        #expect(report.body.contains("Wrong ingredient/quantity"))
    }

    @Test func noteIsOptionalAndTrimmed() {
        let bare = RecipeProblemReport(recipeID: 1, recipeTitle: "A", problemType: .photo, note: "  \n")
        #expect(bare.body == "Recipe: A\nRecipe ID: 1\nProblem: Photo issue")
        let withNote = RecipeProblemReport(
            recipeID: 1,
            recipeTitle: "A",
            problemType: .other,
            note: " 2 tsp, not tbsp "
        )
        #expect(withNote.body.hasSuffix("\n\n2 tsp, not tbsp"))
    }

    @Test func fourProblemTypesInOrder() {
        #expect(
            RecipeProblemType.allCases.map(\.title) == [
                "Wrong ingredient/quantity", "Missing or broken step", "Photo issue", "Other",
            ]
        )
    }
}
