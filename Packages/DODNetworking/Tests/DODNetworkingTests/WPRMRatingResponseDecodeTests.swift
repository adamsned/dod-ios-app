import Foundation
import Testing

@testable import DODNetworking

/// Regression tests for DUT-713: decoding a WPRM rating `count` that is a
/// huge or non-finite JSON number must not trap on `Int(Double)`. The fix
/// in `WPDTO.WPRMRatingResponse.decodeInt` uses `Int(exactly:)` which is
/// failable, degrading to 0 rather than crashing.
@Suite("WPRMRatingResponse decoding (DUT-713)") struct WPRMRatingResponseDecodeTests {

    private let decoder = JSONDecoder()

    /// 1e30 far exceeds Int.max (~9.2e18). Before the fix the Int(Double)
    /// fallback would trap (crash) here. Post-fix: `Int(exactly:)` returns
    /// nil for out-of-range values and decodeInt degrades to 0.
    @Test func pathologicalCountDoesNotTrap() throws {
        let json = Data(#"{"rating":{"average":4.5,"count":1e30}}"#.utf8)
        let response = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: json)
        #expect(response.average == 4.5)
        #expect(response.count == 0)  // swiftlint:disable:this empty_count
    }

    @Test func normalCountDecodes() throws {
        let json = Data(#"{"rating":{"average":4.5,"count":42}}"#.utf8)
        let response = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: json)
        #expect(response.average == 4.5)
        #expect(response.count == 42)
    }

    /// "Infinity" as a JSON string is not a parseable Int —
    /// `Int("Infinity") == nil` — so decodeInt falls through to 0.
    @Test func infinityStringCountDegradesGracefully() throws {
        let json = Data(#"{"rating":{"average":3.0,"count":"Infinity"}}"#.utf8)
        let response = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: json)
        #expect(response.count == 0)  // swiftlint:disable:this empty_count
    }

    /// -1e30 is below Int.min (~-9.2e18); same non-trapping path as positive
    /// overflow.
    @Test func negativeHugeCountDegradesGracefully() throws {
        let json = Data(#"{"rating":{"average":2.0,"count":-1e30}}"#.utf8)
        let response = try decoder.decode(WPDTO.WPRMRatingResponse.self, from: json)
        #expect(response.count == 0)  // swiftlint:disable:this empty_count
    }
}
