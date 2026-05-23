import SwiftUI

/// Non-blocking offline indicator. Slides in from the top when `isOffline`
/// toggles true; slides out on reconnect.
///
/// Apply via a view modifier so any screen can host it:
/// ```swift
/// content.overlay(alignment: .top) { OfflineBanner(isOffline: vm.isOffline) }
/// ```
///
/// Spec trace: spec.md CC-2, AC-1.6.
public struct OfflineBanner: View {

    public let isOffline: Bool
    public let message: String

    public init(isOffline: Bool, message: String = "Offline — showing recent recipes.") {
        self.isOffline = isOffline
        self.message = message
    }

    public var body: some View {
        if isOffline {
            HStack(spacing: DODSpacing.xs) {
                Image(systemName: "wifi.slash")
                    .accessibilityHidden(true)
                Text(message)
                    .dodFont(DODType.caption)
            }
            .foregroundStyle(DODColor.cream)
            .padding(.horizontal, DODSpacing.md)
            .padding(.vertical, DODSpacing.xs)
            .frame(maxWidth: .infinity)
            .background(DODColor.castIronBrown)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Offline. \(message)")
        }
    }
}

#Preview("Online") {
    OfflineBanner(isOffline: false)
}

#Preview("Offline") {
    OfflineBanner(isOffline: true)
}
