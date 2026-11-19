import Foundation
import Testing

@testable import DODSupport

@Suite("DeepLinkIntent pan check route (DUT-1826)") struct DeepLinkIntentPanCheckTests {
    @Test func roundTripsEveryVerdict() {
        for verdict in PanCheck.Verdict.allCases {
            let intent = DeepLinkIntent.openPanCheck(verdict: verdict)
            #expect(DeepLinkIntent.parse(intent.url) == intent)
        }
    }

    @Test func unknownVerdictFallsBackToUnclear() throws {
        let url = try #require(URL(string: "dod://pancheck?verdict=nope"))
        #expect(DeepLinkIntent.parse(url) == .openPanCheck(verdict: .unclear))
    }

    @Test func parsesRustOrCarbon() throws {
        let url = try #require(URL(string: "dod://pancheck?verdict=rustOrCarbon"))
        #expect(DeepLinkIntent.parse(url) == .openPanCheck(verdict: .rustOrCarbon))
    }

    @Test func missingVerdictIsUnclear() throws {
        let url = try #require(URL(string: "dod://pancheck"))
        #expect(DeepLinkIntent.parse(url) == .openPanCheck(verdict: .unclear))
    }
}
