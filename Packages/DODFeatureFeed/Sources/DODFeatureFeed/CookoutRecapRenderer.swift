import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// DUT-976 — renders a recap card to a PNG file for ShareLink.
@MainActor
enum CookoutRecapRenderer {

    static func fileName(for day: Date) -> String {
        "cookout-recap-\(Int(day.timeIntervalSince1970)).png"
    }
}
