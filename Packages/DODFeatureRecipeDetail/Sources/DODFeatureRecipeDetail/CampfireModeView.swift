import SwiftUI

/// DUT-102 - high-contrast, glanceable outdoor cook surface.
struct CampfireModeView: View {
    let variant: CampfireVariant
    let stepText: String
    let stepLabel: String  // e.g. "Step 2 of 6"
    let isFinished: Bool
    let timers: [Int: CookStepTimer]
    let currentStepIndex: Int
    let onPrev: () -> Void
    let onNext: () -> Void
    let onToggleVariant: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Exit", action: onExit)
                    .accessibilityIdentifier("campfire-exit")
                Spacer()
                Text(stepLabel).accessibilityIdentifier("campfire-step-label")
                Spacer()
                Button(variant.toggled.label, action: onToggleVariant)
                    .accessibilityIdentifier("campfire-variant")
            }
            .font(.title3.weight(.bold))

            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let text = CampfireTimerReadout.text(
                    timers: timers,
                    currentStep: currentStepIndex,
                    now: context.date
                ) {
                    Text(text)
                        .font(.system(size: CampfireVariant.timerFontSize, weight: .heavy, design: .monospaced))
                        .minimumScaleFactor(0.5)
                        .accessibilityIdentifier("campfire-timer")
                }
            }

            ScrollView {
                Text(isFinished ? "All done!" : stepText)
                    .font(.system(size: CampfireVariant.stepFontSize, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("campfire-step-text")
            }

            HStack(spacing: 12) {
                navButton("Prev", id: "campfire-prev", action: onPrev)
                navButton(isFinished ? "Close" : "Next", id: "campfire-next", action: onNext)
            }
        }
        .padding(20)
        .foregroundStyle(variant.foreground)
        .background(variant.background.ignoresSafeArea())
    }

    private func navButton(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 36, weight: .heavy))
                .frame(maxWidth: .infinity, minHeight: CampfireVariant.navButtonHeight)
                .background(variant.buttonFill, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
