import Foundation
import Testing

@testable import DODDesignSystem

/// DUT-520: the on-screen hero loader must resolve permanent errors immediately
/// instead of burning a second full fetch, and only retry a genuinely transient
/// connectivity blip. These assert the `URLError` retry policy directly (the
/// non-2xx-status → terminal mapping lives inline in `fetchOnce` and is covered
/// by the build). The policy is platform-independent, so it runs on the macOS
/// test slice even though the loader itself is UIKit-coupled.
@Suite("ReliableImage DUT-520 retry policy")
struct ReliableImageRetryPolicyTests {

    @Test func transientErrorsRetryOnce() {
        let transient: [URLError.Code] = [
            .timedOut, .networkConnectionLost, .cannotConnectToHost,
            .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet,
        ]
        for code in transient {
            #expect(
                ReliableImageRetry.decision(for: URLError(code)) == .retry,
                "\(code) should be retried once"
            )
        }
    }

    @Test func cancellationIsReportedDistinctly() {
        // DUT-201: a recycled cell surfaces as URLError(.cancelled) and must not
        // flip the cell to failure.
        #expect(ReliableImageRetry.decision(for: URLError(.cancelled)) == .cancelled)
    }

    @Test func permanentErrorsAreTerminal() {
        // A bad/unsupported request will never succeed on retry — fail fast so
        // the cell resolves immediately instead of after a second full fetch.
        let terminal: [URLError.Code] = [
            .badURL, .unsupportedURL, .badServerResponse,
            .cannotDecodeContentData, .fileDoesNotExist,
        ]
        for code in terminal {
            #expect(
                ReliableImageRetry.decision(for: URLError(code)) == .terminal,
                "\(code) should be terminal (no retry)"
            )
        }
    }
}
