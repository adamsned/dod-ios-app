import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for the iPad-only gating of the instructions-annotation
/// affordance (Apple Pencil, v2). Pure `Bool` logic, so the "iPhone-hidden /
/// iPad-shown" contract is verified with no SwiftUI hosting.
@Suite("Annotate affordance gating") struct AnnotationGatingTests {

    @Test func shownOnRegularWidthPad() {
        #expect(shouldShowAnnotateAffordance(isRegularWidth: true, isPad: true))
    }

    @Test func hiddenOnCompactWidthPad() {
        // iPad Slide Over / narrow split — reading column is iPhone-narrow.
        #expect(shouldShowAnnotateAffordance(isRegularWidth: false, isPad: true) == false)
    }

    @Test func hiddenOnIPhone() {
        // iPhone is compact + not a pad — the whole feature stays hidden so the
        // reading view is byte-identical.
        #expect(shouldShowAnnotateAffordance(isRegularWidth: false, isPad: false) == false)
    }

    @Test func hiddenOnRegularWidthNonPad() {
        // A regular-width non-pad surface (defensive) still doesn't qualify.
        #expect(shouldShowAnnotateAffordance(isRegularWidth: true, isPad: false) == false)
    }
}
