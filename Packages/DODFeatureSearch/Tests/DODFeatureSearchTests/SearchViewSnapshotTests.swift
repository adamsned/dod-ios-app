#if canImport(UIKit)
import DODDesignSystem
import DODDomain
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureSearch

/// L4 visual-regression coverage for ``SearchView``'s results state across
/// the {light, dark} × {default Dynamic Type, AX5} matrix called out by
/// US-18 / AC-18.1.
///
/// First iOS-sim test run uses `record: .missing` to lay the baseline PNGs
/// down. T-335 follow-up commits them. Spec trace: constitution §6 L4,
/// US-18 AC-18.1, AC-18.2.
final class SearchViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
        // US-38 / AC-38.6 (T-650): ensure each test sees the default
        // `.gallery` layout; the list-layout tests below override.
        UserDefaults.standard.removeObject(forKey: RecipeListLayout.storageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: RecipeListLayout.storageKey)
        super.tearDown()
    }

    @MainActor
    func test_searchResults_light_defaultDynamicType() async {
        let view = await Self.makeHostedSearch()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_searchResults_dark_defaultDynamicType() async {
        let view = await Self.makeHostedSearch()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.darkTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_searchResults_light_AX5() async {
        let view = await Self.makeHostedSearch()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 2_000), traits: Self.lightAX5Traits()),
            record: .missing
        )
    }

    @MainActor
    func test_searchResults_dark_AX5() async {
        let view = await Self.makeHostedSearch()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 2_000), traits: Self.darkAX5Traits()),
            record: .missing
        )
    }

    // MARK: - US-38 / AC-38.4 / AC-38.6 — list-layout baselines (T-650)

    @MainActor
    func test_searchResults_listLayout_light_defaultDynamicType() async {
        UserDefaults.standard.set(
            RecipeListLayout.list.rawValue,
            forKey: RecipeListLayout.storageKey
        )
        let view = await Self.makeHostedSearch()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_searchResults_listLayout_dark_defaultDynamicType() async {
        UserDefaults.standard.set(
            RecipeListLayout.list.rawValue,
            forKey: RecipeListLayout.storageKey
        )
        let view = await Self.makeHostedSearch()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.darkTraits()),
            record: .missing
        )
    }

    // MARK: - Fixtures

    /// Drives a `SearchViewModel` into `.results` with 4 deterministic
    /// recipes for the query "skillet" using `FakeSearchDependencies`,
    /// then hosts it. `runImmediateSearch()` bypasses the 300ms debounce
    /// so the snapshot test is synchronous.
    @MainActor
    static func makeHostedSearch() async -> some View {
        let dependencies = FakeSearchDependencies()
        let items = (1...4).map(Self.makeItem)
        dependencies.results["skillet"] = items
        for item in items {
            dependencies.cachedItemsByID[item.id] = item
        }
        dependencies.categories = [
            .init(id: 1, name: "Beef", slug: "beef", count: 42),
            .init(id: 2, name: "Chicken", slug: "chicken", count: 56),
            .init(id: 3, name: "Sides", slug: "sides", count: 18),
        ]
        let viewModel = SearchViewModel(dependencies: dependencies)
        await viewModel.loadCategoriesIfNeeded()
        // Set query directly so `scheduleSearch` queues, then bypass the
        // debounce with `runImmediateSearch` so the VM lands in `.results`
        // before the snapshot captures the view.
        viewModel.query = "skillet"
        await viewModel.runImmediateSearch()
        return SearchStatefulHost(viewModel: viewModel)
    }

    static func makeItem(_ id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Skillet Recipe \(id)",
            excerpt: "Sample search-result excerpt \(id) — quick weeknight skillet meal.",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: "\(15 + id * 5) min"
        )
    }

    // MARK: - Trait helpers

    static func lightTraits() -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .light),
            UITraitCollection(displayScale: 3),
        ])
    }

    static func darkTraits() -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(displayScale: 3),
        ])
    }

    static func lightAX5Traits() -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .light),
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            UITraitCollection(displayScale: 3),
        ])
    }

    static func darkAX5Traits() -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            UITraitCollection(displayScale: 3),
        ])
    }
}

// MARK: - Stateful host
//
// `SearchView` mounts its own `@State` view-model and wires a TextField
// against `viewModel.query`. The host below installs a pre-`.results`
// view-model inside a `NavigationStack` so the navigation title renders.

@MainActor
private struct SearchStatefulHost: View {
    let viewModel: SearchViewModel

    var body: some View {
        NavigationStack {
            SearchView(viewModel: viewModel, onSelect: { _ in })
        }
    }
}
#endif
