#if canImport(UIKit)
import Foundation
import SwiftUI
import Testing

@testable import DODFeatureFeed

@MainActor
@Suite struct CookoutRecapRendererTests {
    @Test func fileNameIsStable() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(CookoutRecapRenderer.fileName(for: day) == CookoutRecapRenderer.fileName(for: day))
        #expect(CookoutRecapRenderer.fileName(for: day).hasSuffix(".png"))
    }
}
#endif
