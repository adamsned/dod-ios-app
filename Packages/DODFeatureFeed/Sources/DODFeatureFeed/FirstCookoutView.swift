import DODDesignSystem
import DODSupport
import SwiftUI

/// The guided "Your First Cookout" flow (US-53 / AC-53.2 / DUT-183) — the
/// keystone experience that walks a nervous beginner through one guaranteed
/// win, coached by Ned, and lands on the *"I did it"* moment.
///
/// It renders the pure ``GuidedCookout`` content spine as a paged flow:
/// **intro → the four stages (gather / fire / cook / celebrate) → celebration**.
/// This first slice is self-contained — the *cook* stage links out to the
/// lasagna recipe; later slices wire the live engines per stage (the charcoal
/// card at *fire*, the timer + voice at *cook*, the "I Made This" capture at
/// *celebrate*).
public struct FirstCookoutView: View {

    private let cookout: GuidedCookout
    /// Web home of the recipe, used to deep-link the *cook* stage to the dish.
    private let recipeBaseURL: String

    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    /// 0 = intro; 1...steps.count = each coached step; steps.count + 1 = celebration.
    @State private var index = 0

    public init(
        cookout: GuidedCookout = .firstCookout,
        recipeBaseURL: String = "https://www.dutchovendaddy.com"
    ) {
        self.cookout = cookout
        self.recipeBaseURL = recipeBaseURL
    }

    private var lastIndex: Int { cookout.steps.count + 1 }

    public var body: some View {
        VStack(spacing: DODSpacing.lg) {
            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            controls
        }
        .padding(DODSpacing.lg)
        .background(DODColor.surface)
        .animation(.easeInOut(duration: 0.25), value: index)
    }

    // MARK: - Screens

    @ViewBuilder private var screen: some View {
        if index == 0 {
            introScreen
        } else if index <= cookout.steps.count {
            stepScreen(cookout.steps[index - 1])
        } else {
            celebrationScreen
        }
    }

    private var introScreen: some View {
        VStack(spacing: DODSpacing.md) {
            Image(systemName: "flame.fill")
                .font(.system(size: 56))
                .foregroundStyle(DODColor.burntOrange)
            Text("Your First Cookout")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.labelSecondary)
            Text(cookout.dishTitle)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
                .multilineTextAlignment(.center)
            Text(cookout.whyThisDish)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 520)
    }

    private func stepScreen(_ step: GuidedCookout.Step) -> some View {
        VStack(spacing: DODSpacing.md) {
            Image(systemName: stageIcon(step.stage))
                .font(.system(size: 48))
                .foregroundStyle(DODColor.burntOrange)
            Text(step.title)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
                .multilineTextAlignment(.center)
            Text(step.coaching)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
            if step.stage == .fire {
                coalsCard
            }
            if step.stage == .cook {
                Button("Open the \(cookout.dishTitle) recipe") {
                    if let url = URL(string: "\(recipeBaseURL)/\(cookout.recipeSlug)/") {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(DODColor.burntOrange)
                .padding(.top, DODSpacing.xs)
            }
        }
        .frame(maxWidth: 520)
    }

    /// DUT-128 / DUT-183 — the live coal recommendation for the dish at the
    /// *fire* stage: total briquettes + bottom/lid split, so the scariest part
    /// of a first cookout is a concrete number instead of a guess.
    private var coalsCard: some View {
        let coals = CharcoalRecipeConverter.recommend(
            ovenTempF: cookout.ovenTempF,
            ovenDiameterInches: cookout.ovenDiameterInches,
            task: .bake
        )
        return VStack(spacing: DODSpacing.xxs) {
            Text("\(coals.totalBriquettes) coals")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.burntOrange)
            Text("\(coals.bottom) on the bottom · \(coals.top) on the lid")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
            Text(
                "for a \(cookout.ovenDiameterInches)-inch oven at \(cookout.ovenTempF)°F — "
                    + "add a few fresh ones after about \(coals.refreshIntervalMinutes) minutes"
            )
            .dodFont(DODType.caption)
            .foregroundStyle(DODColor.labelSecondary)
            .multilineTextAlignment(.center)
        }
        .padding(DODSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .padding(.top, DODSpacing.xs)
    }

    private var celebrationScreen: some View {
        VStack(spacing: DODSpacing.md) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 56))
                .foregroundStyle(DODColor.burntOrange)
            Text("You did it.")
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
            Text(cookout.celebrationMessage)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .multilineTextAlignment(.center)
            Text(cookout.nextStepPrompt)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, DODSpacing.xs)
        }
        .frame(maxWidth: 520)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack {
            if index > 0 {
                Button("Back") { index -= 1 }
                    .foregroundStyle(DODColor.labelSecondary)
            }
            Spacer()
            progressDots
            Spacer()
            Button(primaryButtonTitle) {
                if index >= lastIndex {
                    dismiss()
                } else {
                    index += 1
                }
            }
            .fontWeight(.semibold)
            .foregroundStyle(DODColor.burntOrange)
        }
    }

    private var progressDots: some View {
        HStack(spacing: DODSpacing.xxs) {
            ForEach(0...lastIndex, id: \.self) { dot in
                Circle()
                    .fill(dot == index ? DODColor.burntOrange : DODColor.labelSecondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityLabel("Step \(index + 1) of \(lastIndex + 1)")
    }

    private var primaryButtonTitle: String {
        if index == 0 { return "Let's cook" }
        if index >= lastIndex { return "Done" }
        return "Next"
    }

    private func stageIcon(_ stage: GuidedCookout.Stage) -> String {
        switch stage {
        case .gather: return "checklist"
        case .fire: return "flame.fill"
        case .cook: return "frying.pan.fill"
        case .celebrate: return "party.popper.fill"
        }
    }
}

#Preview("Intro") {
    FirstCookoutView()
}
