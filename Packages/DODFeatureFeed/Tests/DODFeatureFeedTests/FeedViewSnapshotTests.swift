#if canImport(UIKit)
import DODDesignSystem
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
        // US-38 / AC-38.6 (T-650): ensure each test sees the default
        // `.gallery` layout; the list-layout tests below override.
        UserDefaults.standard.removeObject(forKey: RecipeListLayout.storageKey)
    }

    override func tearDown() {
        // Reset so per-test layout overrides don't leak into other
        // FeedView tests (e.g. the existing `_loadedFeed_*` baselines
        // assume `.gallery`).
        UserDefaults.standard.removeObject(forKey: RecipeListLayout.storageKey)
        super.tearDown()
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

    // MARK: - US-38 / AC-38.4 / AC-38.6 — list-layout baselines (T-650)

    @MainActor
    func test_loadedFeed_listLayout_light_defaultDynamicType() async {
        UserDefaults.standard.set(
            RecipeListLayout.list.rawValue,
            forKey: RecipeListLayout.storageKey
        )
        let view = await Self.makeHostedFeed()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_loadedFeed_listLayout_dark_defaultDynamicType() async {
        UserDefaults.standard.set(
            RecipeListLayout.list.rawValue,
            forKey: RecipeListLayout.storageKey
        )
        let view = await Self.makeHostedFeed()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.darkTraits()),
            record: .missing
        )
    }

    // MARK: - DUT-571 — the top-of-feed First-Cookout hero card

    // The hero's visibility is driven by a `@State` cook-state load that a
    // synchronous snapshot render can't reliably await, so we snapshot the
    // `FirstCookoutHeroCard` unit directly in its first-rung ("Your First
    // Cookout") state — the new-cook surface DUT-571 adds to the top of the Feed.
    // Its gating (new / un-graduated, non-dismissed) is covered by
    // `FeedFirstCookoutHeroTests`.

    @MainActor
    func test_firstCookoutHero_firstRung_light() {
        let view = Self.hostedHeroCard()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 380), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_firstCookoutHero_firstRung_dark() {
        let view = Self.hostedHeroCard()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 380), traits: Self.darkTraits()),
            record: .missing
        )
    }

    /// The First-Cookout hero card seeded to the first rung, padded like the Feed
    /// renders it (top of the recipe list).
    @MainActor
    static func hostedHeroCard() -> some View {
        FirstCookoutHeroCard(
            cookout: .firstCookout,
            onStart: {},
            onDismiss: {},
            onCookDumpCake: {}
        )
        .padding()
        .background(DODColor.surface)
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
            FeedView(viewModel: viewModel, onSelect: { _, _ in })
        }
    }
}
#endif
