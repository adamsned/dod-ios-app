import Testing

@testable import DODFeatureRecipeDetail

/// L1 coverage for the T-912 / DUT-551 (CL-306) Cook Mode Heat Coach
/// heat-step gate: the pure predicate that decides whether a step shows the
/// "Open Heat Coach" shortcut. A step is heat-related when it carries an
/// explicit-unit temperature (via ``TemperatureConverter/fahrenheitValues(in:)``)
/// OR mentions coal / fire language. The shortcut itself is additionally gated
/// on a wired `heatCoachSheet` (host-injected) at the view layer — this pins the
/// content-detection half so a plain step never shows a Heat Coach button and a
/// coals/temperature step always can.
@Suite("Cook Mode heat-step gate (DUT-551)") struct CookModeHeatShortcutTests {

    @Test func explicitTemperatureStepIsHeatRelated() {
        #expect(CookModeView.stepIsHeatRelated("Preheat the oven to 350°F."))
        #expect(CookModeView.stepIsHeatRelated("Bake at 375 °F for 20 minutes."))
    }

    @Test func coalKeywordStepIsHeatRelated() {
        #expect(CookModeView.stepIsHeatRelated("Arrange the coals in a ring under the oven."))
        #expect(CookModeView.stepIsHeatRelated("Let the briquettes ash over before starting."))
        #expect(CookModeView.stepIsHeatRelated("Preheat your Dutch oven."))
    }

    @Test func plainStepIsNotHeatRelated() {
        #expect(!CookModeView.stepIsHeatRelated("Stir in the flour and mix until combined."))
        #expect(!CookModeView.stepIsHeatRelated("Let the dough rest for ten minutes."))
    }

    @Test func detectionIsCaseInsensitive() {
        #expect(CookModeView.stepIsHeatRelated("ADD FRESH COALS every 45 minutes."))
    }
}
