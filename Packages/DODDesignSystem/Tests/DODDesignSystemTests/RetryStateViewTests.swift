import Testing

@testable import DODDesignSystem

@Suite
struct RetryStateViewTests {
    @Test func copyDistinguishesKinds() {
        #expect(LoadFailureKind.noConnection.title != LoadFailureKind.requestFailed.title)
        #expect(!LoadFailureKind.noConnection.message.isEmpty)
        #expect(!LoadFailureKind.requestFailed.message.isEmpty)
    }

    @Test func retryActionFires() {
        var fired = false
        let view = RetryStateView(kind: .noConnection) {
            @MainActor in
            fired = true
        }
        view.retry()
        #expect(fired == true)
    }
}
