#if canImport(UIKit)
import DODDesignSystem
import DODDomain
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureSaved

/// L4 visual-regression coverage for ``SavedView``'s loaded state across
/// the {light, dark} × {default Dynamic Type, AX5} matrix called out by
/// US-18 / AC-18.1.
///
/// First iOS-sim test run uses `record: .missing` to lay the baseline PNGs
/// down. T-335 follow-up commits them. Spec trace: constitution §6 L4,
/// US-18 AC-18.1, AC-18.2.
final class SavedViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
        // DUT-530 — ensure each test sees the default `.gallery` layout; the
        // list-layout tests below override the key and `tearDown` resets it, so
        // the existing grid baselines stay `.gallery`.
        UserDefaults.standard.removeObject(forKey: RecipeListLayout.storageKey)
    }

    override func tearDown() {
        // DUT-530 — reset so a per-test list override doesn't leak into the
        // grid-layout baselines (which assume `.gallery`).
        UserDefaults.standard.removeObject(forKey: RecipeListLayout.storageKey)
        super.tearDown()
    }

    @MainActor
    func test_loadedSaved_light_defaultDynamicType() async {
        let view = await Self.makeHostedSaved()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_loadedSaved_dark_defaultDynamicType() async {
        let view = await Self.makeHostedSaved()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.darkTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_loadedSaved_light_AX5() async {
        let view = await Self.makeHostedSaved()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 1_600), traits: Self.lightAX5Traits()),
            record: .missing
        )
    }

    @MainActor
    func test_loadedSaved_dark_AX5() async {
        let view = await Self.makeHostedSaved()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 1_600), traits: Self.darkAX5Traits()),
            record: .missing
        )
    }

    // MARK: - DUT-530 — list-layout baselines (local-only, not CI-gated)

    @MainActor
    func test_loadedSaved_listLayout_light_defaultDynamicType() async {
        UserDefaults.standard.set(
            RecipeListLayout.list.rawValue,
            forKey: RecipeListLayout.storageKey
        )
        let view = await Self.makeHostedSaved()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_loadedSaved_listLayout_dark_defaultDynamicType() async {
        UserDefaults.standard.set(
            RecipeListLayout.list.rawValue,
            forKey: RecipeListLayout.storageKey
        )
        let view = await Self.makeHostedSaved()
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.darkTraits()),
            record: .missing
        )
    }

    // MARK: - Fixtures

    /// Drives a `SavedViewModel` into `.loaded` with 3 deterministic saved
    /// recipes via the existing `FakeSavedDependencies`, then hosts it.
    @MainActor
    static func makeHostedSaved() async -> some View {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = (1...3).map(Self.makeRecipe)
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        return SavedStatefulHost(viewModel: viewModel)
    }

    static func makeRecipe(_ id: Int) -> Recipe {
        Recipe(
            id: id,
            slug: "saved-\(id)",
            title: "Saved Recipe \(id)",
            excerpt: "A previously-saved recipe with sample excerpt \(id).",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: [.init(text: "salt"), .init(text: "pepper")],
            instructions: [.init(step: 1, text: "Stir.")],
            totalTime: .seconds((15 + id * 5) * 60)
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
// `SavedView` mounts its own `@State` view-model and runs `refresh()`
// inside a `.task` on appear. The host wraps it in `NavigationStack` so
// the "Saved" navigation title renders. Test-target-only.

@MainActor
private struct SavedStatefulHost: View {
    let viewModel: SavedViewModel

    var body: some View {
        NavigationStack {
            SavedView(viewModel: viewModel, onSelect: { _ in })
        }
    }
}
#endif
