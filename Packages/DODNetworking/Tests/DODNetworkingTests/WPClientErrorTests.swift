import Foundation
import Testing

@testable import DODNetworking

@Suite("WPClientError.wrap") struct WPClientErrorTests {

    @Test func passesThroughExistingWPError() {
        let original = WPClientError.httpStatus(503)
        #expect(WPClientError.wrap(original) == .httpStatus(503))
    }

    @Test func mapsNotConnectedToNetworkUnavailable() {
        let error = URLError(.notConnectedToInternet)
        #expect(WPClientError.wrap(error) == .networkUnavailable)
    }

    @Test func mapsTimedOutToTimeout() {
        let error = URLError(.timedOut)
        #expect(WPClientError.wrap(error) == .timeout)
    }

    @Test func mapsOtherURLErrorsToUnderlying() {
        let error = URLError(.badServerResponse)
        guard case .underlying = WPClientError.wrap(error) else {
            Issue.record("Expected .underlying, got \(WPClientError.wrap(error))")
            return
        }
    }
}
