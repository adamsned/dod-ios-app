import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

struct CookPepTalkViewTests {
    private func recipe(total: Duration? = nil, cook: Duration? = nil) -> Recipe {
        Recipe(
            id: 1,
            slug: "s",
            title: "T",
            excerpt: "e",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/1/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            cookTime: cook,
            totalTime: total
        )
    }

    @Test func fortyFiveMinutes() {
        #expect(CookPepTalkView.timeCommitmentText(for: recipe(total: .seconds(45 * 60))) == "About 45 min")
    }

    @Test func ninetyMinutes() {
        #expect(CookPepTalkView.timeCommitmentText(for: recipe(total: .seconds(90 * 60))) == "About 1 hr 30 min")
    }

    @Test func twoHours() {
        #expect(CookPepTalkView.timeCommitmentText(for: recipe(total: .seconds(120 * 60))) == "About 2 hr")
    }

    @Test func fallsBackToCookTime() {
        #expect(CookPepTalkView.timeCommitmentText(for: recipe(cook: .seconds(30 * 60))) == "About 30 min")
    }

    @Test func noTimesIsNil() {
        #expect(CookPepTalkView.timeCommitmentText(for: recipe()) == nil)
    }
}
