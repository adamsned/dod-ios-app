// LossyArrayLossyDecodeTests.swift
//
// Regression tests for DUT-575: LossyArray lossy decode contract.
// Verifies that bad rows are dropped while preserving order and advancing the cursor exactly one.

import Foundation
import Testing
@testable import DODNetworking

private struct Row: Decodable, Equatable {
    let id: Int
}

@Suite struct LossyArrayLossyDecodeTests {

    @Test("All valid rows decode and preserve order")
    func allValidRowsPreserveOrder() throws {
        let json = "[{\"id\":1},{\"id\":2},{\"id\":3}]"
        let decoded = try JSONDecoder().decode(LossyArray<Row>.self, from: Data(json.utf8))

        #expect(decoded.elements == [Row(id: 1), Row(id: 2), Row(id: 3)])
    }

    @Test("Bad object in middle is dropped, following good row survives")
    func badObjectInMiddleDropped() throws {
        let json = "[{\"id\":1},{\"nope\":true},{\"id\":3}]"
        let decoded = try JSONDecoder().decode(LossyArray<Row>.self, from: Data(json.utf8))

        #expect(decoded.elements == [Row(id: 1), Row(id: 3)])
    }

    @Test("Wrong-type scalar element is dropped")
    func wrongTypeScalarElementDropped() throws {
        let json = "[{\"id\":1},\"garbage\",{\"id\":3}]"
        let decoded = try JSONDecoder().decode(LossyArray<Row>.self, from: Data(json.utf8))

        #expect(decoded.elements == [Row(id: 1), Row(id: 3)])
    }

    @Test("Two consecutive bad elements each consume one cursor position")
    func twoConsecutiveBadElementsConsumeTwo() throws {
        let json = "[{\"id\":1},{\"bad\":1},{\"bad\":2},{\"id\":4}]"
        let decoded = try JSONDecoder().decode(LossyArray<Row>.self, from: Data(json.utf8))

        #expect(decoded.elements == [Row(id: 1), Row(id: 4)])
    }

    @Test("All bad rows result in empty array")
    func allBadRowsEmpty() throws {
        let json = "[{\"x\":1},{\"y\":2}]"
        let decoded = try JSONDecoder().decode(LossyArray<Row>.self, from: Data(json.utf8))

        #expect(decoded.elements.isEmpty)
    }

    @Test("Empty input array decodes to empty")
    func emptyArrayDecodesToEmpty() throws {
        let json = "[]"
        let decoded = try JSONDecoder().decode(LossyArray<Row>.self, from: Data(json.utf8))

        #expect(decoded.elements.isEmpty)
    }
}
