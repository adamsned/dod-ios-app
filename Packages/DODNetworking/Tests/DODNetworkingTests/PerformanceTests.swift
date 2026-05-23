import DODDomain
import Foundation
import XCTest

@testable import DODNetworking

/// XCTest-based perf measurements. Swift Testing doesn't (yet) expose a
/// stable equivalent of `XCTMetric` — XCTest stays around for these only.
///
/// Spec trace: CC-7 (performance budgets).
final class JSONLDParserPerformanceTests: XCTestCase {

    /// Parsing the cake fixture should be quick. Locks in the cold-parse
    /// envelope so future parser changes can't silently regress.
    /// Baseline: ~5ms on M1; CI runner may be slower — establish baseline
    /// once and let XCTest's `measureMetrics` enforce a 10% drift gate.
    func testParseCakeFixturePerformance() throws {
        guard let url = Bundle.module.url(forResource: "cake", withExtension: "html") else {
            XCTFail("Fixture missing")
            return
        }
        let html = try String(contentsOf: url, encoding: .utf8)
        let listItem = RecipeListItem(
            id: 1,
            title: "x",
            excerpt: "x",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 0),
            totalTimeDisplay: nil
        )
        let canonical = URL(string: "https://www.dutchovendaddy.com/cake/") ?? URL(filePath: "/")

        measure {
            for _ in 0..<10 {
                _ = try? JSONLDRecipeParser.parse(html: html, merging: listItem, canonicalURL: canonical)
            }
        }
    }
}
