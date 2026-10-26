import Foundation
import Testing

@testable import DODSupport

@MainActor
@Suite("ReviewPromptCoordinator (DUT-157)")
struct ReviewPromptCoordinatorTests {

    private final class Capture {
        var requests = 0
        var signals: [ReviewPromptCoordinator.Signal] = []
    }

    private func make() throws -> (ReviewPromptCoordinator, Capture) {
        let defaults = try #require(UserDefaults(suiteName: "ReviewPromptCoordinatorTests-\(UUID().uuidString)"))
        let cap = Capture()
        let coordinator = ReviewPromptCoordinator(
            store: ReviewPromptStore(defaults: defaults),
            requestReview: { cap.requests += 1 },
            report: { cap.signals.append($0) },
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
        return (coordinator, cap)
    }

    private func engage(_ coordinator: ReviewPromptCoordinator) {
        for _ in 0..<4 { coordinator.recordSession() }
        for _ in 0..<8 { coordinator.recordRecipeView() }
    }

    @Test func belowThresholdsDoesNothing() throws {
        let (coordinator, cap) = try make()
        coordinator.maybePrompt(isCooking: false, hadRecentError: false)
        #expect(cap.requests == 0)
        #expect(cap.signals.isEmpty)
    }

    @Test func eligibleRequestsOnceAndReports() throws {
        let (coordinator, cap) = try make()
        engage(coordinator)
        coordinator.maybePrompt(isCooking: false, hadRecentError: false)
        #expect(cap.requests == 1)
        #expect(cap.signals == [.eligible, .shown])
    }

    @Test func cooldownSuppressesSecondPrompt() throws {
        let (coordinator, cap) = try make()
        engage(coordinator)
        coordinator.maybePrompt(isCooking: false, hadRecentError: false)
        coordinator.maybePrompt(isCooking: false, hadRecentError: false)
        #expect(cap.requests == 1)
    }

    @Test func cookingSuppresses() throws {
        let (coordinator, cap) = try make()
        engage(coordinator)
        coordinator.maybePrompt(isCooking: true, hadRecentError: false)
        #expect(cap.requests == 0)
    }

    @Test func declinedSuppresses() throws {
        let (coordinator, cap) = try make()
        engage(coordinator)
        coordinator.markDeclined()
        coordinator.maybePrompt(isCooking: false, hadRecentError: false)
        #expect(cap.requests == 0)
    }
}
