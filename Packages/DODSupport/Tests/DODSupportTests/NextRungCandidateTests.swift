import Testing

@testable import DODSupport

@Suite("NextRungCandidate") struct NextRungCandidateTests {
    @Test func difficultyIsClampedIntoOneToFive() {
        #expect(NextRungCandidate(recipeID: 1, title: "A", difficulty: 0).difficulty == 1)
        #expect(NextRungCandidate(recipeID: 1, title: "A", difficulty: 9).difficulty == 5)
        #expect(NextRungCandidate(recipeID: 7, title: "A", difficulty: 3).id == 7)
    }
}
