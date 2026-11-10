import DODDomain
import SwiftUI
import Testing

@testable import DODFeatureCategories

@MainActor
@Suite("BrowseByView (DUT-2141)") struct BrowseByViewTests {
    static func makeViewModel() -> BrowseByViewModel {
        let deps = BrowseByFakeCategoriesDependencies()
        deps.itemsByTagIDs[[12]] = [CategoryRecipesViewModelTests.makeItem(1)]
        deps.itemsByTagIDs[[20]] = [CategoryRecipesViewModelTests.makeItem(2)]
        let config = BrowseAxesConfig(axes: [
            BrowseByViewModelTests.axis("course", [("dinner", [12])]),
            BrowseByViewModelTests.axis("occasion", [("holiday", [20])]),
        ])
        return BrowseByViewModel(provider: FakeAxesProvider(result: .success(config)), dependencies: deps)
    }

    @Test func viewBuildsAfterLoadingTwoAxes() async {
        let viewModel = Self.makeViewModel()
        await viewModel.onAppear()
        #expect(viewModel.axes.map(\.slug) == ["course", "occasion"])
        let view = BrowseByView(viewModel: viewModel, onSelect: { _, _ in })
        _ = view.body
    }

    @Test func selectionClosureReceivesValueTagIDs() async throws {
        let viewModel = Self.makeViewModel()
        await viewModel.onAppear()
        var captured: (BrowseAxis, BrowseAxisValue)?
        let onSelect: @MainActor (BrowseAxis, BrowseAxisValue) -> Void = { captured = ($0, $1) }
        _ = BrowseByView(viewModel: viewModel, onSelect: onSelect)
        let axis = try #require(viewModel.axes.first { $0.slug == "occasion" })
        let value = try #require(axis.values.first)
        onSelect(axis, value)
        #expect(captured?.0.slug == "occasion")
        #expect(captured?.1.tagIDs == [20])
    }

    @Test func viewBuildsWithNoAxesOnProviderError() async {
        let viewModel = BrowseByViewModel(
            provider: FakeAxesProvider(result: .failure(BrowseTestError())),
            dependencies: BrowseByFakeCategoriesDependencies()
        )
        await viewModel.onAppear()
        #expect(viewModel.loadState == .error)
        #expect(viewModel.axes.isEmpty)
        let view = BrowseByView(viewModel: viewModel, onSelect: { _, _ in })
        _ = view.body
    }
}
