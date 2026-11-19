import DODDesignSystem
import SwiftUI

/// DUT-1011: landscape-safe Dynamic Island layout — one short row so it fits
/// when the island is width-limited (phone propped sideways). Same inputs as
/// the other layouts; no new data model.
public struct CookActivityLandscapeExpandedView: View {

    public let remainingSeconds: Int
    public let endDate: Date?
    public let isPaused: Bool
    public let isCompleted: Bool

    public init(
        remainingSeconds: Int,
        endDate: Date? = nil,
        isPaused: Bool = false,
        isCompleted: Bool = false
    ) {
        self.remainingSeconds = remainingSeconds
        self.endDate = endDate
        self.isPaused = isPaused
        self.isCompleted = isCompleted
    }

    public var body: some View {
        HStack(alignment: .center, spacing: DODSpacing.sm) {
            CookActivityCompactLeadingView()
                .accessibilityHidden(true)
            CookActivityCompactTrailingView(
                remainingSeconds: remainingSeconds,
                endDate: endDate,
                isPaused: isPaused,
                isCompleted: isCompleted
            )
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            if let label = statusLabel {
                Text(label)
                    .dodFont(DODType.caption)
                    .foregroundStyle(isCompleted ? DODColor.accent : DODColor.labelSecondary)
            }
        }
        .padding(.horizontal, DODSpacing.sm)
        .frame(maxWidth: .infinity)
    }

    /// Exposed for tests.
    var statusLabel: String? {
        cookActivityStatusLabel(isCompleted: isCompleted, isPaused: isPaused)
    }
}
