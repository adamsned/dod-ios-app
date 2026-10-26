import SwiftUI
import Testing

@testable import DODDesignSystem

@Suite("StatusLevel") struct StatusPaletteTests {
    @Test func everyLevelHasDistinctSymbolAndLabel() {
        let symbols = Set(StatusLevel.allCases.map(\.systemImage))
        let labels = Set(StatusLevel.allCases.map(\.defaultLabel))
        #expect(symbols.count == StatusLevel.allCases.count)
        #expect(labels.count == StatusLevel.allCases.count)
    }
}
