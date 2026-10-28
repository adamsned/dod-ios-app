import SwiftUI
import Testing

@testable import DODDesignSystem

#if canImport(UIKit)
@Suite("DODStatusBadge") struct DODStatusBadgeTests {
    @Test func labelDefaultsToLevelLabel() {
        #expect(DODStatusBadge(level: .ready).label == "Ready")
    }

    @Test func customLabelWins() {
        #expect(DODStatusBadge(level: .caution, label: "Too cool").label == "Too cool")
    }
}
#endif
