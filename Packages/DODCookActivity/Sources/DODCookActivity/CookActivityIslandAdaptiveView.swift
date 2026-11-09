import DODDesignSystem
import SwiftUI

/// DUT-1011: picks the expanded-bottom layout for the Dynamic Island. On
/// iOS 27+ it reads `isDynamicIslandLimitedInWidth`; earlier OSes (and
/// macOS test hosts) always get the standard card.
public struct CookActivityIslandAdaptiveView: View {

    public let recipeTitle: String
    public let stepText: String
    public let remainingSeconds: Int
    public let totalSeconds: Int
    public let isPaused: Bool
    public let endDate: Date?
    public let isCompleted: Bool

    public init(
        recipeTitle: String,
        stepText: String,
        remainingSeconds: Int,
        totalSeconds: Int,
        isPaused: Bool,
        endDate: Date? = nil,
        isCompleted: Bool = false
    ) {
        self.recipeTitle = recipeTitle
        self.stepText = stepText
        self.remainingSeconds = remainingSeconds
        self.totalSeconds = totalSeconds
        self.isPaused = isPaused
        self.endDate = endDate
        self.isCompleted = isCompleted
    }

    public var body: some View {
        layout(isLimitedInWidth: false)
    }

    @ViewBuilder
    func layout(isLimitedInWidth: Bool) -> some View {
        switch cookActivityIslandLayout(isLimitedInWidth: isLimitedInWidth) {
        case .landscape:
            CookActivityLandscapeExpandedView(
                remainingSeconds: remainingSeconds,
                endDate: endDate,
                isPaused: isPaused,
                isCompleted: isCompleted
            )
        case .standard:
            CookActivityLockScreenView(
                recipeTitle: recipeTitle,
                stepText: stepText,
                remainingSeconds: remainingSeconds,
                totalSeconds: totalSeconds,
                isPaused: isPaused,
                endDate: endDate,
                isCompleted: isCompleted
            )
        }
    }
}

#if os(iOS)
@available(iOS 27.0, *)
private struct CookActivityLimitedWidthReader: View {
    let content: CookActivityIslandAdaptiveView
    @Environment(\.isDynamicIslandLimitedInWidth) private var isLimitedInWidth

    var body: some View {
        content.layout(isLimitedInWidth: isLimitedInWidth)
    }
}
#endif
