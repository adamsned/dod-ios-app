import Testing
import XCTest

@testable import DODIntelligence

@Suite("CommentDigest")
struct CommentDigestTests {

    @Test("groundedKeepsSupportedTip")
    func groundedKeepsSupportedTip() {
        let sources = ["I brine it an extra hour and it was perfect"]
        let tip = "Brine it an extra hour"
        let digest = CommentDigest(
            summary: "",
            tips: [tip],
            gotchas: []
        )
        let groundedDigest = digest.grounded(in: sources)
        XCTAssertTrue(groundedDigest.tips.contains(tip))
    }

    @Test("groundedDropsFabricatedTip")
    func groundedDropsFabricatedTip() {
        let sources = ["I brine it an extra hour and it was perfect"]
        let tip = "Add saffron and truffle oil"
        let digest = CommentDigest(
            summary: "",
            tips: [tip],
            gotchas: []
        )
        let groundedDigest = digest.grounded(in: sources)
        XCTAssertFalse(groundedDigest.tips.contains(tip))
    }

    @Test("emptyDigestIsEmpty")
    func emptyDigestIsEmpty() {
        let digest = CommentDigest(
            summary: "",
            tips: [],
            gotchas: []
        )
        XCTAssertTrue(digest.isEmpty)
    }
}
