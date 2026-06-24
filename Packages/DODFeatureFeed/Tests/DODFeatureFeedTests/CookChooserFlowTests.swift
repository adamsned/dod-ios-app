import DODSupport
import Testing

@testable import DODFeatureFeed

/// L1 coverage for the DUT-194 / CL-265 chooser's pure path-state logic — the
/// part that decides whether each rung reads as done, the current "start here",
/// or upcoming, given where the cook is on the path.
@Suite("CookChooserFlow (DUT-194 / CL-265)")
struct CookChooserFlowTests {

    // DUT-235 — the chooser is ALWAYS shown (no auto-jump into the first rung).
    // CL-265 — the path renders in natural ladder order (no hoisting); the
    // recommended rung is highlighted in place via its node state.

    @Test func midProgressMapsDoneCurrentUpcoming() {
        let recommended = GuidedCookout.path[1]  // one win logged, on the second rung
        #expect(CookChooserFlow.nodeState(index: 0, recommended: recommended) == .done)
        #expect(CookChooserFlow.nodeState(index: 1, recommended: recommended) == .current)
        #expect(CookChooserFlow.nodeState(index: 2, recommended: recommended) == .upcoming)
    }

    @Test func newCookHasFirstRungCurrentRestUpcoming() {
        let recommended = GuidedCookout.path[0]  // brand-new cook, nothing logged
        #expect(CookChooserFlow.nodeState(index: 0, recommended: recommended) == .current)
        #expect(CookChooserFlow.nodeState(index: 1, recommended: recommended) == .upcoming)
        #expect(CookChooserFlow.nodeState(index: 2, recommended: recommended) == .upcoming)
    }

    @Test func graduateHasEveryRungDone() {
        for index in GuidedCookout.path.indices {
            #expect(CookChooserFlow.nodeState(index: index, recommended: nil) == .done)
        }
    }
}
