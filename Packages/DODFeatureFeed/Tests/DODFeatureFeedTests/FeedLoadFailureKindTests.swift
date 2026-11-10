import Foundation
import Testing

@testable import DODFeatureFeed

@MainActor
@Suite("Feed load failure kind (DUT-1669)") struct FeedLoadFailureKindTests {
    @Test func offlineFirstLaunchMapsToNoConnection() async {
        let dependencies = FakeFeedDependencies()
        dependencies.shouldFail = true
        dependencies.online = false
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .firstLaunchOffline)
        #expect(viewModel.loadFailureKind == .noConnection)
    }

    @Test func onlineFirstLaunchFailureMapsToRequestFailed() async {
        let dependencies = FakeFeedDependencies()
        dependencies.shouldFail = true
        dependencies.online = true
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .firstLaunchFailed)
        #expect(viewModel.loadFailureKind == .requestFailed)
    }
}
