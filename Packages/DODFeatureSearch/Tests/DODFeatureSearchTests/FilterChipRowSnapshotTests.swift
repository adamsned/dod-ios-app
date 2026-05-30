#if canImport(UIKit)
import DODDomain
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureSearch

/// L4 visual-regression coverage focused on ``FilterChipRow``.
///
/// History: pre-T-636 this file locked the `tag.fill` `categoryChip` glyph
/// (US-20 / AC-20.4, post-T-350 swap from `folder`) in both unselected and
/// selected states. T-636 / CL-105 removed the category chip (and the
/// `Recently viewed` toggle chip) because the Categories tab and the
/// Recent searches section already cover those affordances — the chips
/// were duplicative. The row now hosts only `cookTimeChip`; this file is
/// repurposed to lock that chip's idle (unselected) + active (selected)
/// glyph + capsule treatment so the surviving filter affordance keeps
/// L4 visual coverage. First post-T-636 iOS-sim run uses `record: .missing`
/// to lay the new baselines down.
///
/// Scoped to the chip row only — the wider ``SearchView`` baselines
/// (`SearchViewSnapshotTests`) remain owned by T-335 per the spec.
final class FilterChipRowSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    @MainActor
    func test_filterChipRow_unselected_light() {
        let view = Self.makeHostedChipRow(cookTimeMaxSeconds: nil)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 64), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_filterChipRow_unselected_dark() {
        let view = Self.makeHostedChipRow(cookTimeMaxSeconds: nil)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 64), traits: Self.darkTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_filterChipRow_cookTimeSelected_light() {
        // CL-122 / T-644: the bucket fixture (`.under30`) is replaced by
        // the new max-only range (`cookTimeMaxSeconds: 30 * 60`) — chip
        // label re-renders to "30 min or less" instead of "≤ 30 min".
        let view = Self.makeHostedChipRow(cookTimeMaxSeconds: 30 * 60)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 64), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_filterChipRow_cookTimeSelected_dark() {
        let view = Self.makeHostedChipRow(cookTimeMaxSeconds: 30 * 60)
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 390, height: 64), traits: Self.darkTraits()),
            record: .missing
        )
    }

    // MARK: - Fixtures

    /// Renders `FilterChipRow` with optional cook-time max selection
    /// (CL-122 / T-644 — pre-T-644 bucket fixture rewritten to the
    /// min/max model). `cookTimeMaxSeconds: nil` puts the chip in its
    /// idle unselected state ("Any time" + surface-elevated capsule);
    /// passing a value flips the chip into its selected state ("<x> or
    /// less" label + cast-iron-brown capsule), exercising both `isOn`
    /// branches of the chip-label treatment.
    @MainActor
    static func makeHostedChipRow(cookTimeMaxSeconds: Int?) -> some View {
        let filters = SearchFilters(cookTimeMaxSeconds: cookTimeMaxSeconds)
        return FilterChipRowHost(initialFilters: filters)
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

    init(initialFilters: SearchFilters) {
        _filters = State(initialValue: initialFilters)
    }

    var body: some View {
        FilterChipRow(filters: $filters)
    }
}
#endif
