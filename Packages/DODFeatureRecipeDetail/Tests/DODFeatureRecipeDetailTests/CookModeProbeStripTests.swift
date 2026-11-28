import DODSupport
import Foundation
import SwiftUI
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("Cook Mode probe strip view (DUT-2903)") struct CookModeProbeStripTests {
    @Test func buildsWithEmptySession() {
        let strip = CookModeProbeStrip(session: ProbeSession(), recipeID: 1)
        _ = strip.body
        #expect(strip.recipeID == 1)
    }

    @Test func manualEntryUpdatesReading() {
        let session = ProbeSession()
        session.ingestManual(150)
        let strip = CookModeProbeStrip(session: session, recipeID: 1)
        _ = strip.body
        #expect(session.reading?.internalF == 150)
    }
}
