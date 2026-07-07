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
}
