import DODSupport
import XCTest

@testable import DODFeatureFeed

final class FakePanCareNotifier: PanCareNotifying, @unchecked Sendable {
    var scheduled: [(Date, Date)] = []  // (lastActivity, now)
    var cancelCount = 0

    func scheduleIdleReminder(lastActivity: Date, now: Date) async {
        scheduled.append((lastActivity, now))
    }

    func cancelIdleReminder() async {
        cancelCount += 1
    }
}

final class PanCareSchedulingTests: XCTestCase {
    private func makeStore() throws -> PanCareStore {
        let suite = "PanCareSchedulingTests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return PanCareStore(defaults: defaults)
    }

    private func makeCook(at date: Date) -> CookLogEntry {
        CookLogEntry(id: UUID(), recipeID: 1, recipeTitle: "T", cookedAt: date)
    }
}
