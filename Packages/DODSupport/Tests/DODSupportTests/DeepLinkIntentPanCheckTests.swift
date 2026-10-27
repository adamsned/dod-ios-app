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

    @Test func rejectsUnknownVerdict() throws {
        #expect(DeepLinkIntent.parse(try #require(URL(string: "dod://pancheck?verdict=nope"))) == nil)
    }
}
