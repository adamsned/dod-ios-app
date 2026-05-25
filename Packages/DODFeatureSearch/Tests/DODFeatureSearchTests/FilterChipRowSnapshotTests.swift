#if canImport(UIKit)
import DODDomain
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureSearch

/// L4 visual-regression coverage focused on ``FilterChipRow``'s
/// iconography (US-20 / AC-20.4). Locks the `tag.fill` glyph used by
/// `categoryChip` after the T-350 swap from `folder`, in both the
/// unselected (idle) and selected (active filter) chip states across
/// light + dark appearance.
///
/// Scoped to the chip row only — the wider ``SearchView`` baselines
/// (`SearchViewSnapshotTests`) remain owned by T-335 per the spec.
/// First iOS-sim test run uses `record: .missing` to lay the
/// chip-only baselines down.
final class FilterChipRowSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    @MainActor
    func test_filterChipRow_unselected_light() {
        let view = Self.makeHostedChipRow(selectedCategoryID: nil)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 64), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_filterChipRow_unselected_dark() {
        let view = Self.makeHostedChipRow(selectedCategoryID: nil)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 64), traits: Self.darkTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_filterChipRow_categorySelected_light() {
        let view = Self.makeHostedChipRow(selectedCategoryID: 2)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 64), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_filterChipRow_categorySelected_dark() {
        let view = Self.makeHostedChipRow(selectedCategoryID: 2)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 64), traits: Self.darkTraits()),
            record: .missing
        )
    }

    // MARK: - Fixtures

    /// Renders `FilterChipRow` with a deterministic 3-category menu.
    /// `selectedCategoryID: nil` puts the category chip in its idle
    /// unselected state ("All categories" + surface-elevated capsule);
    /// passing an ID flips the chip into its selected state (category
    /// name + cast-iron-brown capsule), exercising both `isOn` branches
    /// of the `tag.fill` glyph treatment from AC-20.1.
    @MainActor
    static func makeHostedChipRow(selectedCategoryID: Int?) -> some View {
        let categories: [DODDomain.Category] = [
            .init(id: 1, name: "Beef", slug: "beef", count: 42),
            .init(id: 2, name: "Chicken", slug: "chicken", count: 56),
            .init(id: 3, name: "Sides", slug: "sides", count: 18),
        ]
        let filters = SearchFilters(categoryID: selectedCategoryID)
        return FilterChipRowHost(initialFilters: filters, categories: categories)
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

// MARK: - Stateful host
//
// `FilterChipRow` takes a `@Binding` for filters, so it needs to live
// inside a view that owns the `@State`. The host below installs a
// pre-seeded `SearchFilters` so the snapshot test can capture both the
// unselected and selected chip states deterministically.

@MainActor
private struct FilterChipRowHost: View {
    @State var filters: SearchFilters
    let categories: [DODDomain.Category]

    init(initialFilters: SearchFilters, categories: [DODDomain.Category]) {
        _filters = State(initialValue: initialFilters)
        self.categories = categories
    }

    var body: some View {
        FilterChipRow(filters: $filters, categories: categories)
    }
}
#endif
