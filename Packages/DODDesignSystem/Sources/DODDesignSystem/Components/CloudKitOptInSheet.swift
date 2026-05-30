import SwiftUI

/// First-launch modal that offers to turn on iCloud Sync (US-41 / AC-41.2,
/// T-704). Built generic — the hosting app (`RootView`) supplies the copy and
/// wires the primary/secondary closures to the CloudKit opt-in seam — so
/// DesignSystem stays decoupled from product strings, exactly like
/// ``OnboardingSheet``.
///
/// Two buttons (unlike ``OnboardingSheet``'s single CTA): a prominent primary
/// ("Turn on iCloud Sync") and a plain secondary ("Not now"). Per AC-41.10 the
/// headline and both buttons carry explicit accessibility labels and the
/// secondary is reachable via VoiceOver swipes; the layout scales to AX5
/// without truncation.
public struct CloudKitOptInSheet: View {

    public let title: String
    public let message: String
    public let primaryTitle: String
    public let secondaryTitle: String
    public let onPrimary: @MainActor () -> Void
    public let onSecondary: @MainActor () -> Void

    public init(
        title: String,
        message: String,
        primaryTitle: String,
        secondaryTitle: String,
        onPrimary: @MainActor @escaping () -> Void,
        onSecondary: @MainActor @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.primaryTitle = primaryTitle
        self.secondaryTitle = secondaryTitle
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DODSpacing.lg) {
                    Image(systemName: "icloud")
                        .font(.system(size: 52, weight: .regular))
                        .foregroundStyle(DODColor.accent)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, DODSpacing.sm)
                        .accessibilityHidden(true)

                    Text(title)
                        .dodFont(DODType.displayLarge)
                        .foregroundStyle(DODColor.label)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)

                    Text(message)
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.labelSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, DODSpacing.xl)
                .padding(.top, DODSpacing.xl + DODSpacing.md)
                .padding(.bottom, DODSpacing.lg)
            }

            VStack(spacing: DODSpacing.sm) {
                primaryButton
                secondaryButton
            }
            .padding(.horizontal, DODSpacing.xl)
            .padding(.bottom, DODSpacing.lg)
            .padding(.top, DODSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DODColor.surface.ignoresSafeArea())
    }

    private var primaryButton: some View {
        Button(action: onPrimary) {
            Text(primaryTitle)
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DODSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                        .fill(DODColor.accent)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(primaryTitle)
    }

    private var secondaryButton: some View {
        Button(action: onSecondary) {
            Text(secondaryTitle)
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DODSpacing.md)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(secondaryTitle)
    }
}

#Preview("iCloud opt-in") {
    CloudKitOptInSheet(
        title: "Sync your saved recipes across devices",
        message: "Turn on iCloud Sync to see your saved recipes on every Apple "
            + "device signed into the same iCloud account.",
        primaryTitle: "Turn on iCloud Sync",
        secondaryTitle: "Not now",
        onPrimary: {},
        onSecondary: {}
    )
}
