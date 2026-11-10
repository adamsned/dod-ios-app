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
}
