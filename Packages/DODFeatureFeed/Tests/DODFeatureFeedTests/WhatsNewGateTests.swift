import Foundation
import Testing

@testable import DODFeatureFeed

@Suite("WhatsNewGate") struct WhatsNewGateTests {
    private func freshDefaults() -> UserDefaults {
        let name = "WhatsNewGateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func freshInstallBaselinesAndDoesNotPresent() {
        let defaults = freshDefaults()
        WhatsNewGate.baselineIfNeeded(currentVersion: "2.0", defaults: defaults)
        #expect(WhatsNewGate.lastSeen(defaults: defaults) == "2.0")
        #expect(
            !WhatsNewGate.shouldPresent(
                currentVersion: "2.0",
                lastSeenVersion: WhatsNewGate.lastSeen(defaults: defaults)
            )
        )
    }

    @Test func baselineDoesNotOverwriteExisting() {
        let defaults = freshDefaults()
        WhatsNewGate.markSeen("2.0", defaults: defaults)
        WhatsNewGate.baselineIfNeeded(currentVersion: "2.5", defaults: defaults)
        #expect(WhatsNewGate.lastSeen(defaults: defaults) == "2.0")
    }

    @Test func presentsOnceAfterUpdate() {
        let defaults = freshDefaults()
        WhatsNewGate.baselineIfNeeded(currentVersion: "2.0", defaults: defaults)
        #expect(
            WhatsNewGate.shouldPresent(
                currentVersion: "2.1",
                lastSeenVersion: WhatsNewGate.lastSeen(defaults: defaults)
            )
        )
        WhatsNewGate.markSeen("2.1", defaults: defaults)
        #expect(
            !WhatsNewGate.shouldPresent(
                currentVersion: "2.1",
                lastSeenVersion: WhatsNewGate.lastSeen(defaults: defaults)
            )
        )
    }

    @Test func numericCompareAndNilLastSeen() {
        #expect(WhatsNewGate.shouldPresent(currentVersion: "2.10", lastSeenVersion: "2.9"))
        #expect(!WhatsNewGate.shouldPresent(currentVersion: "2.0", lastSeenVersion: "2.1"))
        #expect(!WhatsNewGate.shouldPresent(currentVersion: "2.0", lastSeenVersion: nil))
    }
}
