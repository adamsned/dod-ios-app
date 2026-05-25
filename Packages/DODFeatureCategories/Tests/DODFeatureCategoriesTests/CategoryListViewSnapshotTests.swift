#if canImport(UIKit)
import DODDomain
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureCategories

/// L4 visual-regression coverage for ``CategoryListView``'s loaded state.
///
/// The four iPhone 13 baselines (`light/dark` × `default/AX5`) lock the
/// US-18 / AC-18.1 matrix; the two iPad 12.9" baselines (`light/dark` ×
/// `default`) lock the US-19 / AC-19.5 expansion. The implementing PR for
/// T-340 re-recorded the iPhone baselines (the layout changed from
/// `.plain` to `.insetGrouped` with a `.searchable` filter) and added the
/// two iPad-12.9" baselines for the first time.
///
/// First iOS-sim test run uses `record: .missing` to lay any missing
/// baseline PNGs down. Spec trace: constitution §6 L4, US-2 AC-2.1..2.2,
/// US-18 AC-18.1, AC-18.2, US-19 AC-19.1, AC-19.2, AC-19.5.
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

    /// iPad 12.9" baseline — light, default Dynamic Type. Added by T-340
    /// per AC-19.5. AX5 on iPad is intentionally omitted: list rows
    /// don't visually differ from iPhone at AX5 in a way the existing
    /// iPhone AX5 baselines don't already cover.
    @MainActor
    func test_loadedCategories_iPad_light_defaultDynamicType() async {
        let view = await Self.makeHostedList()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 1_024, height: 1_366), traits: Self.lightTraits()),
            record: .missing
        )
    }

    /// iPad 12.9" baseline — dark, default Dynamic Type. Added by T-340
    /// per AC-19.5.
    @MainActor
    func test_loadedCategories_iPad_dark_defaultDynamicType() async {
        let view = await Self.makeHostedList()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 1_024, height: 1_366), traits: Self.darkTraits()),
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
// and (T-340) the `.searchable` field render correctly, and absorbs the
// `onSelect` closure required by the view's init. Test-target-only —
// never in the production target.

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
