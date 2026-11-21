import DODDomain
import DODFeatureRecipeDetail
import DODIntelligence
import Foundation
import Testing

private actor CallCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}

private struct CountingIntelligence: DODIntelligenceService {
    let counter: CallCounter
    var isAvailable: Bool { true }
    var supportsImageInput: Bool { false }

    func suggestSubstitution(
        for ingredient: String,
        in context: RecipeContext?,
        reason: SubstitutionReason?
    ) async -> SubstitutionResult? { nil }
    func summarize(_ text: String) async -> String? { nil }
    func answer(_ question: String, imageData: Data?, recipeContext: String?) async -> String? { nil }

    func summarizeComments(_ comments: [String]) async -> CommentDigest? {
        await counter.increment()
        return .canned
    }
}

@MainActor
struct CommentDigestStoreThresholdTests {
    @Test
    func doesNotRegenerateBelowThreshold() async {
        let counter = CallCounter()
        let store = CommentDigestStore(intelligence: CountingIntelligence(counter: counter))

        await store.refresh(comments: CommentDigestFixtures.approved(3))
        #expect(await counter.count == 1)

        // 4 comments = 1 new, below the threshold of 5 -> no second call.
        await store.refresh(comments: CommentDigestFixtures.approved(4))
        #expect(await counter.count == 1)
        #expect(store.state == .loaded(.canned))

        // 8 comments = 5 new since the digest -> regenerates.
        await store.refresh(comments: CommentDigestFixtures.approved(8))
        #expect(await counter.count == 2)
    }
}
