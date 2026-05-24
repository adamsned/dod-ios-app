#if canImport(UIKit)
import DODDomain
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureCategories

/// L4 visual-regression coverage for ``CategoryListView``'s loaded state
/// across the {light, dark} × {default Dynamic Type, AX5} matrix called
/// out by US-18 / AC-18.1.
///
/// First iOS-sim test run uses `record: .missing` to lay the baseline PNGs
/// down. T-335 follow-up commits them. Spec trace: constitution §6 L4,
/// US-18 AC-18.1, AC-18.2.
final class CategoryListViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    @MainActor
    func test_loadedCategories_light_defaultDynamicType() async {
        let view = await Self.makeHostedList()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_loadedCategories_dark_defaultDynamicType() async {
        let view = await Self.makeHostedList()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.darkTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_loadedCategories_light_AX5() async {
        let view = await Self.makeHostedList()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 1_800), traits: Self.lightAX5Traits()),
            record: .missing
        )
    }

    @MainActor
    func test_loadedCategories_dark_AX5() async {
        let view = await Self.makeHostedList()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 1_800), traits: Self.darkAX5Traits()),
            record: .missing
        )
    }

    // MARK: - Fixtures

    /// Drives a `CategoryListViewModel` into `.loaded` with 8 deterministic
    /// categories via the existing `FakeCategoriesDependencies`, then
    /// hands it to a `CategoryListStatefulHost` for snapshotting.
    @MainActor
    static func makeHostedList() async -> some View {
        let dependencies = FakeCategoriesDependencies()
        dependencies.categories = Self.makeCategories()
        let viewModel = CategoryListViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        return CategoryListStatefulHost(viewModel: viewModel)
    }

    static func makeCategories() -> [DODDomain.Category] {
        [
            .init(id: 1, name: "Beef", slug: "beef", count: 42),
            .init(id: 2, name: "Breakfast", slug: "breakfast", count: 28),
            .init(id: 3, name: "Chicken", slug: "chicken", count: 56),
            .init(id: 4, name: "Desserts", slug: "desserts", count: 33),
            .init(id: 5, name: "One-pot meals", slug: "one-pot", count: 19),
            .init(id: 6, name: "Pasta", slug: "pasta", count: 24),
            .init(id: 7, name: "Sides", slug: "sides", count: 18),
            .init(id: 8, name: "Soups & stews", slug: "soups", count: 22),
        ]
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
// Wraps `CategoryListView` with a `NavigationStack` so the navigation title
// renders, and absorbs the `onSelect` closure required by the view's init.
// Test-target-only — never in the production target.

@MainActor
private struct CategoryListStatefulHost: View {
    let viewModel: CategoryListViewModel

    var body: some View {
        NavigationStack {
            CategoryListView(viewModel: viewModel, onSelect: { _ in })
        }
    }
}
#endif
