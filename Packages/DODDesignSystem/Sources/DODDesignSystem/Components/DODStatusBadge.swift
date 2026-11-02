import SwiftUI

#if canImport(UIKit)
/// DUT-121: status pill that always carries an icon AND a text label in
/// addition to its color, and adds an outline under Differentiate Without Color.
public struct DODStatusBadge: View {
    public let level: StatusLevel
    public let label: String

    public init(level: StatusLevel, label: String? = nil) {
        self.level = level
        self.label = label ?? level.defaultLabel
    }

    public var body: some View {
        HStack(spacing: DODSpacing.xxs) {
            Image(systemName: level.systemImage)
                .accessibilityHidden(true)
            Text(label)
        }
        .dodFont(DODType.caption)
        .foregroundStyle(level.color)
        .padding(.horizontal, DODSpacing.xs)
        .padding(.vertical, DODSpacing.xxs)
        .background(Capsule().fill(level.color.opacity(0.15)))
        .dodStatusOutline(level)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

#Preview("All levels") {
    VStack(alignment: .leading, spacing: DODSpacing.sm) {
        DODStatusBadge(level: .caution, label: "Too cool")
        DODStatusBadge(level: .ready)
        DODStatusBadge(level: .danger, label: "Too hot")
        DODStatusBadge(level: .info)
    }
    .padding(DODSpacing.md)
}
#endif
