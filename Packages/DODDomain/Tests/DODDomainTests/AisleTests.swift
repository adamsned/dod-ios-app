import Foundation
import Testing

@testable import DODDomain

/// L1 coverage for ``Aisle`` — the closed-set enum that drives shopping-list
/// grouping per US-39 / AC-39.4.
///
/// Spec trace: US-39 / AC-39.4 (aisle grouping render), AC-39.10
/// (raw-value telemetry payload), CL-67 (case set).
@Suite("Aisle value type") struct AisleTests {

    /// Every case has a unique, contiguous-from-zero `sortIndex`. Pins the
    /// store-walk render order — adding a new case forces a curator
    /// decision on where it slots in the walk path.
    @Test func allCases_sortIndexIsStableAndContiguousFromZero() {
        let indices = Aisle.allCases.map(\.sortIndex).sorted()
        #expect(indices == Array(0..<Aisle.allCases.count))
        // Sanity-check the explicit ordering matches the doc-comment
        // "staples first, .other last" intent.
        let sortedCases = Aisle.allCases.sorted { $0.sortIndex < $1.sortIndex }
        #expect(sortedCases.first == .produce)
        #expect(sortedCases.last == .other)
    }

    /// Every case has a non-empty `displayName`. Cheap header-safety
    /// pin — a future contributor adding a case won't ship an empty
    /// section title by accident.
    @Test func displayNamesAreNonEmpty() {
        for aisle in Aisle.allCases {
            #expect(!aisle.displayName.isEmpty, "Aisle \(aisle) has empty displayName")
        }
    }

    /// The raw-value strings are the **wire format** for both SwiftData
    /// persistence (T-682's `aisleRaw: String` column) and analytics
    /// (AC-39.10's `shoppingListItemAdded(aisle:)` payload). Renaming
    /// any of these silently breaks both — pinning each value here
    /// makes that a compile-test failure instead.
    @Test func rawValuesAreStableWireFormat() {
        #expect(Aisle.produce.rawValue == "produce")
        #expect(Aisle.pantry.rawValue == "pantry")
        #expect(Aisle.dairy.rawValue == "dairy")
        #expect(Aisle.meat.rawValue == "meat")
        #expect(Aisle.spices.rawValue == "spices")
        #expect(Aisle.bakery.rawValue == "bakery")
        #expect(Aisle.frozen.rawValue == "frozen")
        #expect(Aisle.other.rawValue == "other")
    }

    /// JSON-Codable round-trip on every case — guards against the
    /// raw-value Codable synthesis silently diverging from the
    /// explicit `rawValue` strings if a future contributor adds a
    /// custom `init(from:)`.
    @Test func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for aisle in Aisle.allCases {
            let encoded = try encoder.encode(aisle)
            let decoded = try decoder.decode(Aisle.self, from: encoded)
            #expect(decoded == aisle, "Round-trip failed for \(aisle)")
        }
    }
}
