#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureSaved

/// L4 visual-regression coverage for ``ShoppingListView``'s loaded state with
/// the mock fixture, light + dark (CL-82 / US-39 AC-39.4). Mirrors the
/// `SavedViewSnapshotTests` harness: `record: .missing` lays the baseline PNGs
/// down on the first iOS-sim run. Constitution §6 L4.
final class ShoppingListViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    @MainActor
    func test_shoppingList_light() {
        assertSnapshot(
            of: Self.hosted(),
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_shoppingList_dark() {
        assertSnapshot(
            of: Self.hosted(),
            as: .image(layout: .fixed(width: 390, height: 844), traits: Self.darkTraits()),
            record: .missing
        )
    }

    // MARK: - Fixture

    @MainActor
    static func hosted() -> some View {
        NavigationStack {
            ShoppingListView(viewModel: .mock)
        }
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
}
#endif
