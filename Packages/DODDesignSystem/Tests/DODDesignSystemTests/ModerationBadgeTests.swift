import SwiftUI
import Testing

@testable import DODDesignSystem

@Suite("ModerationBadge status tokens") struct ModerationBadgeTests {

    @Test func moderationBadgeKindsStayDistinguishable() {
        // Three kinds, three distinct cases; no reliance on color alone.
        let kinds: [ModerationBadge.Kind] = [.awaitingApproval, .posted, .failed]
        #expect(Set(kinds.map { String(describing: $0) }).count == 3)
    }
}
