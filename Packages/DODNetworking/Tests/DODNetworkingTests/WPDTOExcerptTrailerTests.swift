import Foundation
import Testing

@testable import DODNetworking

/// DUT-688: WordPress' "read more" trailer arrives as `[…] Continue reading`,
/// but the bracketed ellipsis can be the literal `…` character OR an
/// un-decoded entity (`&hellip;` / `&#8230;`). The trailer strip must remove
/// all three forms so no dangling `[…]` bracket leaks into list-row excerpts —
/// while leaving mid-body prose that merely mentions "continue reading" alone.
@Suite("WPDTO.strippingMoreLink trailer (DUT-688)") struct WPDTOExcerptTrailerTests {

    @Test("Entity-form [&hellip;] trailer is stripped whole, no dangling bracket")
    func stripsHellipEntityTrailer() {
        let result = WPDTO.strippingMoreLink("Body text [&hellip;] Continue reading")
        #expect(result == "Body text")
    }

    @Test("Numeric-entity [&#8230;] trailer is stripped whole")
    func stripsNumericEntityTrailer() {
        let result = WPDTO.strippingMoreLink("Body text [&#8230;] Continue reading")
        #expect(result == "Body text")
    }

    @Test("Literal-ellipsis […] trailer still strips (unchanged behavior)")
    func stripsLiteralEllipsisTrailer() {
        let result = WPDTO.strippingMoreLink("Body text […] Continue reading")
        #expect(result == "Body text")
    }

    @Test("Mid-body 'continue reading' prose is left untouched")
    func leavesMidBodyProseAlone() {
        let input = "Continue reading the recipe below for the full method."
        #expect(WPDTO.strippingMoreLink(input) == input)
    }

    // MARK: - Regex-caching parity (DUT)

    /// The trailing `<a class="more-link">…</a>` element (nested inside the
    /// excerpt paragraph, so `</p>` follows) is stripped whole — guards the
    /// `.range(of:options:)` → cached `NSRegularExpression` translation.
    @Test("more-link anchor element (with trailing </p>) is stripped whole")
    func stripsMoreLinkAnchorElement() {
        let input = #"<p>Body text <a class="more-link" href="/x">Continue reading</a></p>"#
        // The anchor pattern also consumes the trailing `</p>` and any run
        // between `</a>` and end-of-string; the leading `<p>Body text ` remains.
        #expect(WPDTO.strippingMoreLink(input) == "<p>Body text ")
    }

    /// An excerpt carrying neither affordance passes through untouched via the
    /// cheap early-out — no regex pass runs.
    @Test("Excerpt without either affordance is returned unchanged (early-out)")
    func passesThroughPlainExcerpt() {
        let input = "<p>A short plain excerpt with no read-more trailer.</p>"
        #expect(WPDTO.strippingMoreLink(input) == input)
    }
}
