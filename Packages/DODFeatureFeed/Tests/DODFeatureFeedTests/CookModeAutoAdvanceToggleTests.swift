import DODSupport
import SwiftUI
import Testing

@testable import DODFeatureFeed

@Suite("CookModeAutoAdvanceToggle (DUT-173)")
struct CookModeAutoAdvanceToggleTests {
    @Test func preferenceKeyIsNonEmpty() {
        #expect(!CookModeAutoAdvance.preferenceKey.isEmpty)
    }

    @Test @MainActor func toggleViewConstructs() {
        _ = CookModeAutoAdvanceToggle().body
    }
}
