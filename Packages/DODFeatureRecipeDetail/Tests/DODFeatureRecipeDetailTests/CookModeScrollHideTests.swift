import CoreGraphics
import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for the DUT-599 pure scroll → control-visibility rule
/// (`CookModeScrollHide.action`): scroll DOWN collapses the controls, scroll UP
/// brings them back, with a jitter threshold and no effect on the Done card.
@Suite("Cook Mode scroll-to-hide (DUT-599)")
struct CookModeScrollHideTests {

    @Test func scrollDownWhileExpandedCollapses() {
        #expect(
            CookModeScrollHide.action(deltaY: 40, controlsExpanded: true, isFinished: false) == .collapse
        )
    }

    @Test func scrollUpWhileCollapsedExpands() {
        #expect(
            CookModeScrollHide.action(deltaY: -40, controlsExpanded: false, isFinished: false) == .expand
        )
    }

    @Test func scrollDownWhileAlreadyCollapsedIsNoOp() {
        #expect(
            CookModeScrollHide.action(deltaY: 40, controlsExpanded: false, isFinished: false) == nil
        )
    }

    @Test func scrollUpWhileAlreadyExpandedIsNoOp() {
        #expect(
            CookModeScrollHide.action(deltaY: -40, controlsExpanded: true, isFinished: false) == nil
        )
    }

    @Test func subThresholdJitterIsIgnored() {
        #expect(
            CookModeScrollHide.action(deltaY: 4, controlsExpanded: true, isFinished: false) == nil
        )
        #expect(
            CookModeScrollHide.action(deltaY: -4, controlsExpanded: false, isFinished: false) == nil
        )
    }

    @Test func finishedNeverChanges() {
        #expect(
            CookModeScrollHide.action(deltaY: 40, controlsExpanded: true, isFinished: true) == nil
        )
        #expect(
            CookModeScrollHide.action(deltaY: -40, controlsExpanded: false, isFinished: true) == nil
        )
    }
}
