import DODDomain
import Foundation
import Testing

@testable import DODNetworking

@Suite("WPRMRatingsClient.summary") struct WPRMRatingsClientSummaryTests {

    @Test func decodesWrappedShape() async throws {
        // Documented WPRM response shape.
        let wrapped = #"""
            { "rating": { "total": 10, "count": 2, "average": 5 } }
            """#
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "rating/recipe", json: Data(wrapped.utf8))
        let client = WPRMRatingsClient(httpClient: fake)

        let summary = try await client.summary(forRecipeID: 21238)
        #expect(summary.recipeID == 21238)
        #expect(summary.average == 5.0)
        #expect(summary.count == 2)
        #expect(summary.userRating == nil)
    }

    @Test func decodesFlatShape() async throws {
        let flat = #"""
            { "average": 4.5, "count": 12 }
            """#
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "rating/recipe", json: Data(flat.utf8))
        let client = WPRMRatingsClient(httpClient: fake)

        let summary = try await client.summary(forRecipeID: 1)
        #expect(summary.average == 4.5)
        #expect(summary.count == 12)
    }

    @Test func decodesRatingSummaryFromFixture() async throws {
        // The captured live fixture is a 401 body — REG-14 says we degrade
        // to a zero-rating instead of throwing. Replay the 401 status the
        // live endpoint returned.
        let data = try loadFixture("rating-summary")
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "rating/recipe", json: data, statusCode: 401)
        let client = WPRMRatingsClient(httpClient: fake)

        let summary = try await client.summary(forRecipeID: 21238)
        #expect(summary.recipeID == 21238)
        #expect(summary.average == 0)
        #expect(summary.count == 0)  // swiftlint:disable:this empty_count
    }

    @Test func degradesGracefullyOn403() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "rating/recipe", json: Data("{}".utf8), statusCode: 403)
        let client = WPRMRatingsClient(httpClient: fake)

        let summary = try await client.summary(forRecipeID: 7)
        #expect(summary.average == 0)
        #expect(summary.count == 0)  // swiftlint:disable:this empty_count
    }

    @Test func degradesGracefullyOnGarbageBody() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "rating/recipe", json: Data("not json".utf8))
        let client = WPRMRatingsClient(httpClient: fake)

        // REG-14: a decode hiccup still yields a usable zero-rating.
        let summary = try await client.summary(forRecipeID: 7)
        #expect(summary.average == 0)
        #expect(summary.count == 0)  // swiftlint:disable:this empty_count
    }

    @Test func hits5xxStillThrows() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "rating/recipe", json: Data("{}".utf8), statusCode: 500)
        let client = WPRMRatingsClient(httpClient: fake)
        await #expect(throws: WPClientError.httpStatus(500)) {
            _ = try await client.summary(forRecipeID: 7)
        }
    }
}

@Suite("WPRMRatingsClient.postRating") struct WPRMRatingsClientPostTests {

    @Test func postRatingSendsRecipeIDStarsNameEmail() async throws {
        let fake = FakeHTTPClient()
        // Stub both the POST and the follow-up summary GET.
        await fake.stub(urlContaining: "rating/recipe", json: Data(#"{"rating":{"average":5,"count":3}}"#.utf8))
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
        let client = WPRMRatingsClient(httpClient: fake)

        let result = try await client.postRating(
            recipeID: 21238,
            stars: 5,
            authorName: "Reviewer",
            authorEmail: "r@example.com"
        )

        // POST request should be the first captured request.
        let captured = await fake.capturedRequests
        let post = try #require(captured.first { $0.httpMethod == "POST" })
        let body = try #require(post.httpBody)
        let json = try #require(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        #expect(json["recipe_id"] as? Int == 21238)
        #expect(json["rating"] as? Int == 5)
        #expect(json["name"] as? String == "Reviewer")
        #expect(json["email"] as? String == "r@example.com")
        // Returned summary tags userRating with the value just posted.
        #expect(result.userRating == 5)
        #expect(result.recipeID == 21238)
        #expect(result.average == 5.0)
        #expect(result.count == 3)
    }

    @Test func postSucceedsButSummaryGetFailsReturnsSubmittedStar() async throws {
        // DUT-305: the side-effecting POST returned 2xx (the rating WAS
        // recorded), but the best-effort follow-up summary GET 5xx's. The
        // submit must NOT throw and must NOT degrade to a zeroed aggregate —
        // it returns a RecipeRating built from the star just submitted.
        let fake = FakeHTTPClient()
        // Summary GET fails hard (500 throws inside `summary(forRecipeID:)`).
        // Registered first so it wins over the broader "/rating" POST route.
        await fake.stub(urlContaining: "rating/recipe", json: Data("{}".utf8), statusCode: 500)
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
        let client = WPRMRatingsClient(httpClient: fake)

        let result = try await client.postRating(
            recipeID: 21238,
            stars: 4,
            authorName: "Reviewer",
            authorEmail: "r@example.com"
        )

        // Non-zero rating built from the submitted star — never a 0/0 blank.
        #expect(result.recipeID == 21238)
        #expect(result.userRating == 4)
        #expect(result.average == 4.0)
        #expect(result.count == 1)
    }

    @Test func outOfRangeStarsLowThrows() async throws {
        let fake = FakeHTTPClient()
        let client = WPRMRatingsClient(httpClient: fake)
        await #expect(throws: WPClientError.self) {
            _ = try await client.postRating(
                recipeID: 1,
                stars: 0,
                authorName: "T",
                authorEmail: "t@example.com"
            )
        }
    }

    @Test func outOfRangeStarsHighThrows() async throws {
        let fake = FakeHTTPClient()
        let client = WPRMRatingsClient(httpClient: fake)
        await #expect(throws: WPClientError.self) {
            _ = try await client.postRating(
                recipeID: 1,
                stars: 6,
                authorName: "T",
                authorEmail: "t@example.com"
            )
        }
    }

    @Test func auth401IsPropagated() async throws {
        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "/rating") { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(filePath: "/"),
                statusCode: 401,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )
            guard let response else {
                throw WPClientError.underlying(message: "Could not synthesize response")
            }
            return (Data("{}".utf8), response)
        }
        let client = WPRMRatingsClient(httpClient: fake)
        await #expect(throws: WPClientError.httpStatus(401)) {
            _ = try await client.postRating(
                recipeID: 1,
                stars: 5,
                authorName: "T",
                authorEmail: "t@example.com"
            )
        }
    }
}

// MARK: - Domain invariants

@Suite("RecipeRating invariants (REG-14)") struct RecipeRatingInvariantTests {

    @Test func averageClampedToZeroFive() {
        let high = RecipeRating(recipeID: 1, average: 99, count: 1)
        #expect(high.average == 5.0)
        let low = RecipeRating(recipeID: 1, average: -1, count: 1)
        #expect(low.average == 0.0)
    }

    @Test func countNeverNegative() {
        let rating = RecipeRating(recipeID: 1, average: 4.5, count: -3)
        #expect(rating.count == 0)  // swiftlint:disable:this empty_count
    }
}

// MARK: - helpers

private func loadFixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle.module.url(forResource: name, withExtension: "json"),
        "Fixture \(name).json not found in test bundle"
    )
    return try Data(contentsOf: url)
}
