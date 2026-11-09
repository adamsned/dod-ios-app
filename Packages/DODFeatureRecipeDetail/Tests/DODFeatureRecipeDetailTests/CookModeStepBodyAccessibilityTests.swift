import Testing

@testable import DODFeatureRecipeDetail

@Suite("CookMode step body accessibility (DUT-116)")
struct CookModeStepBodyAccessibilityTests {
    @Test func labelUsesPositionAndTotal() {
        #expect(
            CookModeView.stepAccessibilityLabel(
                number: 3,
                total: 8,
                text: "Sear the short ribs 4 minutes per side."
            )
                == "Step 3 of 8. Sear the short ribs 4 minutes per side."
        )
    }
    @Test func labelNeverReportsTotalBelowPosition() {
        #expect(
            CookModeView.stepAccessibilityLabel(number: 2, total: 0, text: "Stir.")
                == "Step 2 of 2. Stir."
        )
    }
}
