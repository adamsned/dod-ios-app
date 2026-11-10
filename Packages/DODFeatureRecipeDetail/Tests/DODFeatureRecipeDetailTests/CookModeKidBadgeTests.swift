import DODDomain
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("Cook Mode kid-safe badge (DUT-2044)") struct CookModeKidBadgeTests {

    @Test func badgeTextIsStable() {
        #expect(CookModeView.kidSafeBadgeText == "Kids can help with this one")
    }

    @Test func badgeGatedOnKidModeAndSafeStep() {
        let viewModel = CookModeViewModelTests.makeViewModel(stepCount: 2)
        let safe = RecipeInstruction(step: 1, text: "Stir the sauce.")
        let knife = RecipeInstruction(step: 2, text: "Chop the onion.")
        #expect(
            CookModeView.showsKidBadge(
                isKidModeEnabled: viewModel.isKidModeEnabled,
                isKidSafe: viewModel.isKidSafe(safe)
            ) == false
        )
        viewModel.isKidModeEnabled = true
        #expect(
            CookModeView.showsKidBadge(
                isKidModeEnabled: viewModel.isKidModeEnabled,
                isKidSafe: viewModel.isKidSafe(safe)
            ) == true
        )
        #expect(
            CookModeView.showsKidBadge(
                isKidModeEnabled: viewModel.isKidModeEnabled,
                isKidSafe: viewModel.isKidSafe(knife)
            ) == false
        )
    }

    @Test func accessibilityLabelIncludesBadgeOnlyWhenShown() {
        #expect(CookModeView.stepAccessibilityLabel(step: 2, text: "Stir.", showBadge: false) == "Step 2. Stir.")
        #expect(
            CookModeView.stepAccessibilityLabel(step: 2, text: "Stir.", showBadge: true)
                == "Step 2. Kids can help with this one. Stir."
        )
    }
}
