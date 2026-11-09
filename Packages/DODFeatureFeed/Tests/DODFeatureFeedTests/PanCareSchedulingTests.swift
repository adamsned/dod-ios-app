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

    func testOneCookSchedulesOnceWithCookDate() async throws {
        let notifier = FakePanCareNotifier()
        let cook = makeCook(at: Date(timeIntervalSince1970: 1_000))
        await PanCareScheduling.reschedule(
            notifier: notifier,
            store: try makeStore(),
            cooks: [cook],
            now: Date(timeIntervalSince1970: 2_000)
        )
        XCTAssertEqual(notifier.scheduled.count, 1)
        XCTAssertEqual(notifier.scheduled.first?.0, cook.cookedAt)
        XCTAssertEqual(notifier.cancelCount, 0)
    }

    func testNoActivityCancelsAndNeverSchedules() async throws {
        let notifier = FakePanCareNotifier()
        await PanCareScheduling.reschedule(
            notifier: notifier,
            store: try makeStore(),
            cooks: [],
            now: Date(timeIntervalSince1970: 2_000)
        )
        XCTAssertEqual(notifier.cancelCount, 1)
        XCTAssertTrue(notifier.scheduled.isEmpty)
    }

    func testNewerCareEntryBecomesLastActivity() async throws {
        let notifier = FakePanCareNotifier()
        let store = try makeStore()
        store.logCare(at: Date(timeIntervalSince1970: 5_000))
        let cook = makeCook(at: Date(timeIntervalSince1970: 1_000))
        await PanCareScheduling.reschedule(
            notifier: notifier,
            store: store,
            cooks: [cook],
            now: Date(timeIntervalSince1970: 6_000)
        )
        XCTAssertEqual(notifier.scheduled.first?.0, Date(timeIntervalSince1970: 5_000))
    }
}
