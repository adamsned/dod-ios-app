import SwiftUI
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
struct CampfireModeViewTests {
    @Test func buildsForBothVariants() {
        #expect(CampfireVariant.allCases.count == 2)
        for variant in CampfireVariant.allCases {
            let view = CampfireModeView(
                variant: variant,
                stepText: "Sear the steak over the coals.",
                stepLabel: "Step 2 of 6",
                isFinished: false,
                timers: [1: CookStepTimer(totalSeconds: 90, state: .paused(remaining: 60))],
                currentStepIndex: 1,
                onPrev: {},
                onNext: {},
                onToggleVariant: {},
                onExit: {}
            )
            _ = view.body
        }
    }

    @Test func buildsWhenFinishedWithNoTimers() {
        let view = CampfireModeView(
            variant: .night,
            stepText: "",
            stepLabel: "Done",
            isFinished: true,
            timers: [:],
            currentStepIndex: 0,
            onPrev: {},
            onNext: {},
            onToggleVariant: {},
            onExit: {}
        )
        _ = view.body
    }
}
