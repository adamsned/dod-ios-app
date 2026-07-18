import DODAnalytics
import DODDomain
import DODNetworking
import DODPersistence
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// Zero-coverage telemetry-firing contract for LiveRecipeDetailDependencies'
/// `postRating` and `postComment` methods. These methods ALWAYS fire telemetry,
/// but ONLY AFTER the underlying network call succeeds — if the client throws,
/// the function re-throws immediately and telemetry is never reached.
///
/// Before this addition, `RatingFetchDegradeTests.swift` and the Fake
/// dependencies' no-throw stubs meant the live fire-on-success paths had zero
/// test coverage. This suite pins those paths + the failure case (no telemetry).
/// Uses `Telemetry.shared.replaceTransport(RecordingTelemetryTransport())` to
/// intercept events without touching the real TelemetryDeck SDK.
///
/// The suite is `.serialized` because `Telemetry.shared` is a process-global
/// singleton; each test restores the default transport in a defer block.
@Suite("LiveRecipeDetailDependencies postRating/postComment telemetry", .serialized)
struct LiveDependenciesPostTelemetryTests {

    @Test func postRatingSendsRecipeRatedTelemetryAfterSuccessfulNetworkCall() async throws {
        let recorder = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(recorder)
        defer { Telemetry.shared.replaceTransport(TelemetryDeckTransport()) }

        let deps = try await makeLiveDepWithFakeRatings(
            fakeHTTPSetup: { fake in
                await fake.stub(
                    urlContaining: "rating/recipe",
                    json: Data(#"{"rating":{"average":5,"count":3}}"#.utf8)
                )
                await fake.stub(urlContaining: "/rating") { request in
                    let response = HTTPURLResponse(
                        url: request.url ?? URL(filePath: "/"),
                        statusCode: 200,
                        httpVersion: "HTTP/1.1",
                        headerFields: ["Content-Type": "application/json"]
                    )
                    guard let response else {
                        throw WPClientError.underlying(message: "Could not synthesize response")
                    }
                    return (Data("{}".utf8), response)
                }
            }
        )

        let result = try await deps.postRating(
            recipeID: 21238,
            stars: 5,
            name: "Reviewer",
            email: "r@example.com"
        )

        #expect(result.userRating == 5)
        #expect(result.recipeID == 21238)

        let recipeEvents = filterRecipeEvents(from: recorder)
        #expect(recipeEvents.count == 1)
        #expect(recipeEvents.first == .recipeRated(recipeID: 21238, stars: 5))
    }

    @Test func postRatingDoesNotSendTelemetryWhenNetworkCallThrows() async throws {
        let recorder = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(recorder)
        defer { Telemetry.shared.replaceTransport(TelemetryDeckTransport()) }

        let deps = try await makeLiveDepWithFakeRatings { fake in
            await fake.stub(
                urlContaining: "rating",
                json: Data(#"{"code":"error","message":"Bad request"}"#.utf8),
                statusCode: 400
            )
        }

        await #expect(throws: WPClientError.self) {
            _ = try await deps.postRating(
                recipeID: 21238,
                stars: 5,
                name: "Reviewer",
                email: "r@example.com"
            )
        }

        let recipeEvents = filterRecipeEvents(from: recorder)
        #expect(recipeEvents.isEmpty)
    }

    @Test func postCommentTelemetryAwaitingApprovalFalseWhenApproved() async throws {
        let recorder = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(recorder)
        defer { Telemetry.shared.replaceTransport(TelemetryDeckTransport()) }

        let fakeComments = FakeHTTPClient()
        let approvedResponse = #"""
            {
              "id": 999, "post": 21238, "parent": 0,
              "author_name": "Reviewer",
              "date_gmt": "2026-05-04T12:00:00",
              "content": { "rendered": "<p>Tasty.</p>" },
              "status": "approved",
              "meta": { "wprm_comment_rating": 5 }
            }
            """#
        await fakeComments.stub(
            urlContaining: "comments",
            json: Data(approvedResponse.utf8),
            statusCode: 201
        )

        let deps = try makeLiveDepWithFakeComments(fakeComments)

        let result = try await deps.postComment(
            postID: 21238,
            body: "Tasty.",
            name: "Reviewer",
            email: "r@example.com",
            rating: 5
        )

        #expect(result.status == .approved)
        #expect(result.id == 999)

        let recipeEvents = filterRecipeEvents(from: recorder)
        #expect(recipeEvents.count == 1)
        #expect(recipeEvents.first == .recipeCommentSubmitted(recipeID: 21238, awaitingApproval: false))
    }

    @Test func postCommentTelemetryAwaitingApprovalTrueWhenHold() async throws {
        let recorder = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(recorder)
        defer { Telemetry.shared.replaceTransport(TelemetryDeckTransport()) }

        let fakeComments = FakeHTTPClient()
        let holdResponse = #"""
            {
              "id": 1, "post": 1, "parent": 0,
              "author_name": "Pending",
              "date_gmt": "2026-05-04T12:00:00",
              "content": { "rendered": "ok" },
              "status": "hold",
              "meta": {}
            }
            """#
        await fakeComments.stub(
            urlContaining: "comments",
            json: Data(holdResponse.utf8),
            statusCode: 201
        )

        let deps = try makeLiveDepWithFakeComments(fakeComments)

        let result = try await deps.postComment(
            postID: 1,
            body: "ok",
            name: "Pending",
            email: "p@example.com",
            rating: nil
        )

        #expect(result.status == .hold)

        let recipeEvents = filterRecipeEvents(from: recorder)
        #expect(recipeEvents.count == 1)
        #expect(recipeEvents.first == .recipeCommentSubmitted(recipeID: 1, awaitingApproval: true))
    }

    @Test func postCommentDoesNotSendTelemetryWhenNetworkCallThrows() async throws {
        let recorder = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(recorder)
        defer { Telemetry.shared.replaceTransport(TelemetryDeckTransport()) }

        let fakeComments = FakeHTTPClient()
        let errorResponse = #"""
            {"code":"rest_comment_content_invalid","message":"Comment content is invalid.","data":{"status":400}}
            """#
        await fakeComments.stub(
            urlContaining: "comments",
            json: Data(errorResponse.utf8),
            statusCode: 400
        )

        let deps = try makeLiveDepWithFakeComments(fakeComments)

        await #expect(throws: WPClientError.self) {
            _ = try await deps.postComment(
                postID: 1,
                body: "x",
                name: "T",
                email: "t@example.com",
                rating: nil
            )
        }

        let recipeEvents = filterRecipeEvents(from: recorder)
        #expect(recipeEvents.isEmpty)
    }

    // MARK: - Helpers

    private func makeLiveDepWithFakeRatings(
        fakeHTTPSetup: (FakeHTTPClient) async -> Void
    ) async throws -> LiveRecipeDetailDependencies {
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)
        let fakeRatings = FakeHTTPClient()
        await fakeHTTPSetup(fakeRatings)

        return LiveRecipeDetailDependencies(
            client: WPRestClient(),
            fetcher: RecipePageFetcher(),
            store: store,
            monitor: NetworkMonitor.shared,
            commentsClient: WPCommentsClient(),
            ratingsClient: WPRMRatingsClient(httpClient: fakeRatings),
            guestIdentity: NoopGuestIdentityStore(),
            savedWidgetPublisher: nil
        )
    }

    private func makeLiveDepWithFakeComments(
        _ fakeComments: FakeHTTPClient
    ) throws
        -> LiveRecipeDetailDependencies
    {  // swiftlint:disable:this opening_brace
        let container = try RecipeStore.inMemoryContainer()
        let store = RecipeStore(modelContainer: container)

        return LiveRecipeDetailDependencies(
            client: WPRestClient(),
            fetcher: RecipePageFetcher(),
            store: store,
            monitor: NetworkMonitor.shared,
            commentsClient: WPCommentsClient(httpClient: fakeComments),
            ratingsClient: WPRMRatingsClient(),
            guestIdentity: NoopGuestIdentityStore(),
            savedWidgetPublisher: nil
        )
    }

    private func filterRecipeEvents(from recorder: RecordingTelemetryTransport) -> [AnalyticsEvent] {
        recorder.events.filter { event in
            switch event {
            case .recipeRated, .recipeCommentSubmitted:
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - Test Helpers

private struct NoopGuestIdentityStore: GuestIdentityStoring {
    func load() throws -> GuestIdentity? { nil }
    func save(_ identity: GuestIdentity) throws {}
    func clear() throws {}
}
