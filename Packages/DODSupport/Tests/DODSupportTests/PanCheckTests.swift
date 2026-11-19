import XCTest

@testable import DODSupport

@available(iOS 17.0, *)
final class PanCheckTests: XCTestCase {
    func testRustLabelAt06() throws {
        let labels = [(identifier: "rust", confidence: 0.6 as Float)]
        XCTAssertEqual(PanCheck.verdict(fromLabels: labels), .rustOrCarbon)
    }

    func testSkilletAt08() throws {
        let labels = [(identifier: "skillet", confidence: 0.8 as Float)]
        XCTAssertEqual(PanCheck.verdict(fromLabels: labels), .wellSeasoned)
    }

    func testBothPresentRustWins() throws {
        let labels = [
            (identifier: "rust", confidence: 0.6 as Float), (identifier: "skillet", confidence: 0.8 as Float),
        ]
        XCTAssertEqual(PanCheck.verdict(fromLabels: labels), .rustOrCarbon)
    }

    func testRustAt01() throws {
        let labels = [(identifier: "rust", confidence: 0.1 as Float)]
        XCTAssertEqual(PanCheck.verdict(fromLabels: labels), .unclear)
    }

    func testEmptyArray() throws {
        let labels: [(identifier: String, confidence: Float)] = []
        XCTAssertEqual(PanCheck.verdict(fromLabels: labels), .unclear)
    }

    func testAllVerdictsHaveNonEmptyHeadlineAndAdvice() throws {
        for verdict in PanCheck.Verdict.allCases {
            XCTAssertFalse(verdict.headline.isEmpty)
            XCTAssertFalse(verdict.advice.isEmpty)
        }
    }
}
