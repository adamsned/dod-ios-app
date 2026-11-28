import SwiftUI

/// DUT-126: chip shown on a recipe for diet fit or an allergen warning.
public struct DietaryBadge: View {
    public enum Kind: Equatable, Sendable {
        case fitsDiet
        case allergenWarning(String)  // e.g. "Contains Nuts"
        case unverified  // recipe lacks ingredient data; never claims safe
    }

    public let kind: Kind
    public init(kind: Kind) { self.kind = kind }

    /// Exposed for tests and VoiceOver.
    public var text: String {
        switch kind {
        case .fitsDiet: "Fits your diet"
        case .allergenWarning(let name): name
        case .unverified: "Allergens unverified"
        }
    }

    private var symbol: String {
        switch kind {
        case .fitsDiet: "checkmark.circle"
        case .allergenWarning: "exclamationmark.triangle.fill"
        case .unverified: "questionmark.circle"
        }
    }

    private var tint: Color {
        switch kind {
        case .fitsDiet: DODColor.labelSecondary
        case .allergenWarning: DODColor.burntOrange
        case .unverified: DODColor.labelSecondary
        }
    }

    public var body: some View {
        HStack(spacing: DODSpacing.xxs) {
            Image(systemName: symbol).accessibilityHidden(true)
            Text(text)
        }
        .dodFont(DODType.detail)
        .foregroundStyle(tint)
        .padding(.horizontal, DODSpacing.sm)
        .padding(.vertical, DODSpacing.xs)
        .overlay(Capsule().stroke(tint, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

#Preview("Dietary badges") {
    VStack(spacing: DODSpacing.md) {
        DietaryBadge(kind: .fitsDiet)
        DietaryBadge(kind: .allergenWarning("Contains Nuts"))
        DietaryBadge(kind: .unverified)
    }
    .padding(DODSpacing.md)
}
