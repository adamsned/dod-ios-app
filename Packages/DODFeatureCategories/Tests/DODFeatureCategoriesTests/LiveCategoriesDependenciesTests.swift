import DODDomain
import DODNetworking
import DODPersistence
import Foundation
import Testing

@testable import DODFeatureCategories

private final class StubCategoriesHTTPClient: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URL] = []
    private let status: Int
    private let body: Data
    private let headers: [String: String]

    init(json: String, status: Int = 200, headers: [String: String] = [:]) {
        self.body = Data(json.utf8)
        self.status = status
        self.headers = headers
    }

    var requestedURLs: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    private func record(_ url: URL) {
        lock.lock()
        recorded.append(url)
        lock.unlock()
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url ?? URL(fileURLWithPath: "/")
        record(url)
        guard
            let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: nil, headerFields: headers)
        else { throw URLError(.badServerResponse) }
        return (body, response)
    }
}

@Suite("LiveCategoriesDependencies") struct LiveCategoriesDependenciesTests {

    private func makeLive(
        json: String,
        status: Int = 200,
        headers: [String: String] = [:]
    ) throws -> (LiveCategoriesDependencies, StubCategoriesHTTPClient) {
        let http = StubCategoriesHTTPClient(json: json, status: status, headers: headers)
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        let live = LiveCategoriesDependencies(client: WPRestClient(httpClient: http), store: store)
        return (live, http)
    }

    @Test func fetchCategoriesSortsAlphabeticallyAndHidesEmpty() async throws {
        let json = """
            [{"id":2,"name":"beta","slug":"beta","count":3},
             {"id":1,"name":"Alpha","slug":"alpha","count":5},
             {"id":3,"name":"Empty","slug":"empty","count":0}]
            """
        let (live, _) = try makeLive(json: json)
        let categories = try await live.fetchCategories()
        #expect(categories.map(\.name) == ["Alpha", "beta"])
    }

    @Test func fetchCategoriesWithEmptyArrayReturnsEmpty() async throws {
        let (live, _) = try makeLive(json: "[]")
        #expect(try await live.fetchCategories().isEmpty)
    }

    @Test func fetchCategoriesPropagatesHTTPFailure() async throws {
        let (live, _) = try makeLive(json: "[]", status: 500)
        await #expect(throws: WPClientError.self) {
            _ = try await live.fetchCategories()
        }
    }
    
    @Test func postsPageReturnsEmptyForInvalidID() async throws {
        let json = """
            []
            """
        let (live, _) = try makeLive(json: json)
        let (items, totalPages) = try await live.fetchPosts(categoryID: 999, page: 1)
        #expect(items.isEmpty)
        #expect(totalPages == 1)
    }
    
    @Test func postsPageReturnsCorrectData() async throws {
        let json = """
            [{"id":1,"title":"Post 1","excerpt":"","heroImage":null,"publishedAt":"2023-01-01T00:00:00Z","totalTimeDisplay":"30m"}]
            """
        let (live, _) = try makeLive(json: json)
        let (items, totalPages) = try await live.fetchPosts(categoryID: 1, page: 1)
        #expect(items.count == 1)
        #expect(totalPages == 1)
    }
    
    @Test func postsPageHandlesHTTPFailure() async throws {
        let (live, _) = try makeLive(json: "[]", status: 404)
        await #expect(throws: WPClientError.self) {
            _ = try await live.fetchPosts(categoryID: 1, page: 1)
        }
    }
}