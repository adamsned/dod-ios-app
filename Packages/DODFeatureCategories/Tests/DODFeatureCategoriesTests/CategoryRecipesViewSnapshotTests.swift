#if canImport(UIKit)
import DODDomain
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureCategories

/// L4 visual-regression coverage for ``CategoryRecipesView``'s loaded state
/// (the per-category recipe grid) across the {light, dark} ×
/// {default Dynamic Type, AX5} matrix called out by US-18 / AC-18.1.
///
/// First iOS-sim test run uses `record: .missing` to lay the baseline PNGs
/// down. T-335 follow-up commits them. Spec trace: constitution §6 L4,
/// US-18 AC-18.1, AC-18.2.
final class CategoryRecipesViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    @MainActor
    func test_loadedRecipes_light_defaultDynamicType() async {
        let view = await Self.makeHostedRecipes()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_loadedRecipes_dark_defaultDynamicType() async {
        let view = await Self.makeHostedRecipes()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.darkTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_loadedRecipes_light_AX5() async {
        let view = await Self.makeHostedRecipes()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 2_800), traits: Self.lightAX5Traits()),
            record: .missing
        )
    }

    @MainActor
    func test_loadedRecipes_dark_AX5() async {
        let view = await Self.makeHostedRecipes()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 2_800), traits: Self.darkAX5Traits()),
            record: .missing
        )
    }

    // MARK: - Fixtures

    /// Drives a `CategoryRecipesViewModel` into `.loaded` with 8
    /// deterministic recipes for category 336 ("Desserts") via the
    /// existing `FakeCategoriesDependencies`, then hosts it.
    @MainActor
    static func makeHostedRecipes() async -> some View {
        let dependencies = FakeCategoriesDependencies()
        dependencies.posts[1] = (1...8).map(Self.makeItem)
        let category = DODDomain.Category(id: 336, name: "Desserts", slug: "desserts", count: 8)
        let viewModel = CategoryRecipesViewModel(category: category, dependencies: dependencies)
        await viewModel.onAppear()
        return CategoryRecipesStatefulHost(viewModel: viewModel)
    }

    static func makeItem(_ id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Dessert \(id)",
            excerpt: "A sample dessert recipe for category snapshot row \(id).",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: "\(20 + id * 5) min"
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
// `CategoryRecipesView` requires a `CategoryRecipesViewModel` plus an
// `onSelect` callback. Wrapped in `NavigationStack` so the category title
// renders.

@MainActor
private struct CategoryRecipesStatefulHost: View {
    let viewModel: CategoryRecipesViewModel

    var body: some View {
        NavigationStack {
            CategoryRecipesView(viewModel: viewModel, onSelect: { _ in })
        }
    }
}
#endif
