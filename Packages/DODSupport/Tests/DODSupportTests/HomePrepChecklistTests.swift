import DODDomain
import Foundation
import Testing

@testable import DODSupport

@Suite("HomePrepChecklist") struct HomePrepChecklistTests {
    private func recipe(_ texts: [String]) -> Recipe {
        Recipe(
            id: 1,
            slug: "s",
            title: "T",
            excerpt: "",
            canonicalURL: URL(fileURLWithPath: "/x"),
            publishedAt: Date(),
            instructions: texts.enumerated().map { RecipeInstruction(step: $0.offset + 1, text: $0.element) }
        )
    }

    @Test func onlyHomeStepsIncluded() {
        let list = HomePrepChecklist.build(from: recipe(["Dice the onion", "Place coals on lid"]))
        #expect(list.items.count == 1)
        #expect(list.items.first?.step == 1)
    }

    @Test func parsesMinutes() {
        let list = HomePrepChecklist.build(from: recipe(["Chill the sauce for 30 minutes"]))
        #expect(list.items.first?.minutes == 30)
    }

    @Test func totalSumsKnownMinutes() {
        let list = HomePrepChecklist.build(
            from: recipe([
                "Chill the sauce for 10 minutes",
                "Boil the pasta for 20 minutes",
                "Chop the peppers",
            ])
        )
        #expect(list.items.count == 3)
        #expect(list.items[2].minutes == nil)
        #expect(list.totalMinutes == 30)
    }

    @Test func emptyWhenNoHomeSteps() {
        let list = HomePrepChecklist.build(from: recipe(["Place coals on lid", "Serve hot"]))
        #expect(list.isEmpty)
        #expect(list.totalMinutes == 0)
    }
}
