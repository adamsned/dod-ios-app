#if canImport(UIKit)
import DODDomain
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureFeed

/// L4 visual-regression coverage for ``FeedView``'s loaded state across the
/// {light, dark} × {default Dynamic Type, AX5} matrix called out by US-18 /
/// AC-18.1.
///
/// First iOS-sim test run uses `record: .missing` to lay the baseline PNGs
/// down. T-335 follow-up commits them. Spec trace: constitution §6 L4,
/// US-18 AC-18.1, AC-18.2.
final class FeedViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    @MainActor
    func test_loadedFeed_light_defaultDynamicType() async {
        let view = await Self.makeHostedFeed()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_loadedFeed_dark_defaultDynamicType() async {
        let view = await Self.makeHostedFeed()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.darkTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_loadedFeed_light_AX5() async {
        let view = await Self.makeHostedFeed()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 2_400), traits: Self.lightAX5Traits()),
            record: .missing
        )
    }

    @MainActor
    func test_loadedFeed_dark_AX5() async {
        let view = await Self.makeHostedFeed()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 2_400), traits: Self.darkAX5Traits()),
            record: .missing
        )
    }

    // MARK: - Fixtures

    /// Drives a `FeedViewModel` into `.loaded` with 6 deterministic rows
    /// using the existing `FakeFeedDependencies` test double, then hands
    /// it to a `FeedStatefulHost` for snapshotting. The view-model's
    /// `onAppear` runs synchronously here because the fake's `fetchPosts`
    /// returns immediately and the connectivity stream never emits.
    @MainActor
    static func makeHostedFeed() async -> some View {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...6).map(Self.makeItem)
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.onAppear()
        return FeedStatefulHost(viewModel: viewModel)
    }

    static func makeItem(_ id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Recipe \(id)",
            excerpt:
                "Sample excerpt for recipe number \(id) used in feed snapshot tests.",
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
// `FeedView` requires a `FeedViewModel` it can install into its own `@State`,
// plus an `onSelect` closure. The host below boxes those concerns so the
// snapshot tests only have to talk about "a feed prepopulated to this state".
// Lives in the test target — never in the production target — per the
// T-332 working rules.

@MainActor
private struct FeedStatefulHost: View {
    let viewModel: FeedViewModel

    var body: some View {
        NavigationStack {
            FeedView(viewModel: viewModel, onSelect: { _ in })
        }
    }
}
#endif
