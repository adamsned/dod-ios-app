import SwiftUI
import Testing

@testable import DODDesignSystem

@Suite("AvailabilityBadge tests") struct AvailabilityBadgeTests {

    @Test func labelsDiffer() {
        #expect(OfflineAvailability.worksOffline.label == "Works offline")
        #expect(OfflineAvailability.needsNetwork.label == "Needs network")
    }

    @Test func glyphOnlyConstructs() {
        let badge = AvailabilityBadge(.worksOffline, style: .glyphOnly)
        #expect(badge.style == .glyphOnly)
    }
}
