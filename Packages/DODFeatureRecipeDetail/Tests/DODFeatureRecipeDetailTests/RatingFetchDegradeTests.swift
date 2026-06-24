import DODDomain
import DODNetworking
import DODPersistence
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-303 — the REAL REG-14 safety net: `LiveRecipeDetailDependencies`
/// `.fetchRatingSummary` must swallow a throw from `ratingsClient.summary(...)`
/// and degrade to a 0/0 `RecipeRating`, never propagate it. The protocol method
/// is non-throwing and `RecipeDetailViewModel.loadRatingsAndComments()` calls it
/// with no try/catch, so a propagated error would abort the whole load and the
/// comments would never render.
///
/// The pre-existing "offline" cache tests asserted this via `online = false`,
/// but the Fake's `fetchRatingSummary` never reads `online` and never throws —
/// so the live `do/catch` (the thing that actually protects the screen) had zero
/// coverage. This pins it against the real `WPRMRatingsClient`, driven by an
/// HTTP transport that throws.
@Suite("REG-14 rating-fetch failure-degrade (DUT-303)")
struct RatingFetchDegradeTests {

    @Test func fetchRatingSummaryDegradesToZeroWhenTheRatingsClientThrows() async throws {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        // A real WPRMRatingsClient whose transport throws → `summary(...)`
        // propagates the error (it only self-degrades offline / 401 / 403 / decode
        // hiccups; a 5xx or transport failure throws), so this exercises the live
        // `fetchRatingSummary` catch — not a Fake short-circuit.
        let deps = LiveRecipeDetailDependencies(
            client: WPRestClient(),
            fetcher: RecipePageFetcher(),
            store: store,
            monitor: NetworkMonitor.shared,
            commentsClient: WPCommentsClient(),
            ratingsClient: WPRMRatingsClient(httpClient: ThrowingHTTPClient()),
            guestIdentity: NoopGuestIdentityStore(),
            savedWidgetPublisher: nil
        )

        let rating = await deps.fetchRatingSummary(recipeID: 21238)

        // Degraded, not thrown: a safe 0/0 the screen can render around.
        // (Locals dodge the `empty_count` lint — `count` here is a rating tally.)
        let degradedAverage = rating.average
        let degradedCount = rating.count
        #expect(rating.recipeID == 21238)
        #expect(degradedAverage == 0)
        #expect(degradedCount == 0)
        #expect(rating.userRating == nil)
    }
}

/// HTTP transport that always throws a non-`networkUnavailable` error, so
/// `WPRMRatingsClient.summary` re-throws it (rather than self-degrading) and the
/// live `fetchRatingSummary` catch is the only thing standing between the throw
/// and the view model.
private struct ThrowingHTTPClient: HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw URLError(.badServerResponse)
    }
}

private struct NoopGuestIdentityStore: GuestIdentityStoring {
    func load() throws -> GuestIdentity? { nil }
    func save(_ identity: GuestIdentity) throws {}
    func clear() throws {}
}
