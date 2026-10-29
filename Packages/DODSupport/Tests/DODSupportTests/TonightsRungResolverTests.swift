import Foundation
import Testing

@testable import DODSupport

@Suite("TonightsRungResolver (DUT-989)")
struct TonightsRungResolverTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(_ id: Int, _ title: String, at seconds: TimeInterval) -> CookLogEntry {
        CookLogEntry(
            id: UUID(),
            recipeID: id,
            recipeTitle: title,
            cookedAt: Date(timeIntervalSince1970: seconds)
        )
    }

    @Test func inProgressWinsOverLastCooked() {
        let progress = TonightsRungResolver.InProgress(recipeID: 7, title: "Brisket", stepNumber: 3)
        let log = [entry(1, "Chili", at: 100)]
        let result = TonightsRungResolver.resolve(inProgress: progress, cookLog: log, now: now)
        #expect(result?.kind == .resume)
        #expect(result?.recipeID == 7)
        #expect(result?.title == "Brisket")
        #expect(result?.stepNumber == 3)
        #expect(result?.writtenAt == now)
    }

    @Test func fallsBackToMostRecentCookLogEntry() {
        let log = [entry(1, "Chili", at: 100), entry(2, "Ribs", at: 200)]
        let result = TonightsRungResolver.resolve(inProgress: nil, cookLog: log, now: now)
        #expect(result?.kind == .cook)
        #expect(result?.recipeID == 2)
        #expect(result?.title == "Ribs")
        #expect(result?.stepNumber == nil)
    }

    @Test func emptyReturnsNil() {
        #expect(TonightsRungResolver.resolve(inProgress: nil, cookLog: [], now: now) == nil)
    }

    @Test func stepNumberClampedToAtLeastOne() {
        let progress = TonightsRungResolver.InProgress(recipeID: 7, title: "Brisket", stepNumber: 0)
        let result = TonightsRungResolver.resolve(inProgress: progress, cookLog: [], now: now)
        #expect(result?.stepNumber == 1)
    }

    @Test func nonPositiveRecipeIDIgnored() {
        let progress = TonightsRungResolver.InProgress(recipeID: 0, title: "Bad", stepNumber: 2)
        let log = [entry(-1, "Bad", at: 300), entry(5, "Wings", at: 100)]
        let result = TonightsRungResolver.resolve(inProgress: progress, cookLog: log, now: now)
        #expect(result?.kind == .cook)
        #expect(result?.recipeID == 5)
        let none = TonightsRungResolver.resolve(
            inProgress: progress,
            cookLog: [entry(0, "Bad", at: 1)],
            now: now
        )
        #expect(none == nil)
    }
}
