import SwiftUI

/// Reusable empty / error state. One title, one body line, an optional CTA.
///
/// Spec trace: spec.md CC-4 (error states), AC-1.5 (first-launch offline),
/// AC-2.5, AC-3.4, AC-5.8.
public struct EmptyState: View {

    public struct Action {
        public let title: String
        public let handler: @MainActor () -> Void

        public init(title: String, handler: @MainActor @escaping () -> Void) {
            self.title = title
            self.handler = handler
        }
    }

    public let systemImage: String
    public let title: String
    public let message: String
    public let action: Action?

    public init(
        systemImage: String = "tray",
        title: String,
        message: String,
        action: Action? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.action = action
    }

    public var body: some View {
        VStack(spacing: DODSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DODColor.labelSecondary)
                .accessibilityHidden(true)

            VStack(spacing: DODSpacing.xs) {
                Text(title)
                    .dodFont(DODType.displayMedium)
                    .foregroundStyle(DODColor.label)
                    .multilineTextAlignment(.center)

                Text(message)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
                    .multilineTextAlignment(.center)
            }

            if let action {
                Button(action: action.handler) {
                    Text(action.title)
                        .dodFont(DODType.bodyEmphasized)
                        .padding(.horizontal, DODSpacing.lg)
                        .padding(.vertical, DODSpacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(DODColor.accent)
            }
        }
        .padding(DODSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DODColor.surface)
    }
}

#Preview("Empty list") {
    EmptyState(
        systemImage: "heart",
        title: "No saved recipes yet",
        message: "Tap the heart on any recipe to save it for offline."
    )
}

#Preview("Error with retry") {
    EmptyState(
        systemImage: "wifi.slash",
        title: "You need internet",
        message: "Connect to load recipes the first time.",
        action: .init(title: "Retry") {}
    )
}
