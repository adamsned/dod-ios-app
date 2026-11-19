import DODFeatureFeed
import SwiftUI
import UIKit

extension Notification.Name {
    static let deviceDidShake = Notification.Name("DODDeviceDidShake")
}

/// DUT-176 — UIWindow forwards motion events; post a notification when a shake ends.
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

extension AppTab {
    /// Stable, non-PII screen id for feedback diagnostics.
    var shakeScreenID: String {
        switch self {
        case .feed: "feed"
        case .saved: "saved"
        case .cookingTools: "cooking_tools"
        }
    }
}

struct ShakeToReport: ViewModifier {
    let currentScreen: String
    @State private var isPresenting = false

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                isPresenting = true
            }
            .sheet(isPresented: $isPresenting) {
                FeedbackSheetView(currentScreen: currentScreen)
            }
    }
}
