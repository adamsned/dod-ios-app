import SwiftUI

/// Whether a recipe is fully usable with no network (DUT-134).
public enum OfflineAvailability: Sendable, Equatable {
    case worksOffline  // fully cached: card/body + images
    case needsNetwork  // partial: images not prefetched or card not downloaded

    public var label: String {
        switch self {
        case .worksOffline: "Works offline"
        case .needsNetwork: "Needs network"
        }
    }
    public var systemImage: String {
        switch self {
        case .worksOffline: "checkmark.circle.fill"
        case .needsNetwork: "icloud.and.arrow.down"
        }
    }
}

public struct AvailabilityBadge: View {
    public enum Style: Sendable { case labeled, glyphOnly }
    public let availability: OfflineAvailability
    public let style: Style
    public init(_ availability: OfflineAvailability, style: Style = .labeled) {
        self.availability = availability
        self.style = style
    }
    public var body: some View {
        Group {
            switch style {
            case .labeled:
                Label(availability.label, systemImage: availability.systemImage)
                    .dodFont(DODType.caption)
            case .glyphOnly:
                Image(systemName: availability.systemImage)
            }
        }
        .foregroundStyle(availability == .worksOffline ? DODColor.accent : DODColor.labelSecondary)
        .accessibilityLabel(availability.label)
    }
}
