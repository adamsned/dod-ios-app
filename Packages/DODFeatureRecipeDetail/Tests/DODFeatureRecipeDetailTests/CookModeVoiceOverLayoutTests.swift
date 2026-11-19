import SwiftUI
import Testing

@testable import DODFeatureRecipeDetail

@Suite("CookMode VoiceOver layout (DUT-116)")
struct CookModeVoiceOverLayoutTests {
    @Test func swipeGestureDisabledForTheViewItselfWhenVoiceOverRuns() {
        #expect(CookModeView.swipeGestureMask(voiceOverEnabled: true) == .subviews)
    }

    @Test func swipeGestureFullyEnabledWithoutVoiceOver() {
        #expect(CookModeView.swipeGestureMask(voiceOverEnabled: false) == .all)
    }
}
