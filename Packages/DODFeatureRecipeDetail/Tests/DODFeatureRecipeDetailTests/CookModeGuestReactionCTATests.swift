import SwiftUI
import Testing

@testable import DODFeatureRecipeDetail

@Suite("Cook Mode guest reaction CTA (DUT-981)")
struct CookModeGuestReactionCTATests {

    @Test func showsGuestReactionCTA_whenFinishedAndHasSink() {
        #expect(CookModeView.showsGuestReactionCTA(isFinished: true, hasSink: true) == true)
    }

    @Test func doesNotShowGuestReactionCTA_whenNotFinished() {
        #expect(CookModeView.showsGuestReactionCTA(isFinished: false, hasSink: true) == false)
    }

    @Test func doesNotShowGuestReactionCTA_whenNoSink() {
        #expect(CookModeView.showsGuestReactionCTA(isFinished: true, hasSink: false) == false)
    }
}
