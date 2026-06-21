import DODDesignSystem
import DODSupport
import PhotosUI
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// The guided "Your First Cookout" flow (US-53 / AC-53.2 / DUT-183) — the
/// keystone that walks a nervous beginner through one guaranteed win, coached by
/// Ned, and lands on the *"I did it"* moment. Renders the pure ``GuidedCookout``
/// spine as a paged flow (intro → gather → fire → cook → celebrate) and wires the
/// built engines in per stage. The stage-specific views live in
/// `FirstCookoutView+Stages.swift`.
public struct FirstCookoutView: View {

    let cookout: GuidedCookout
    /// Web home of the recipe; the *cook* stage opens `base/<slug>/` which the
    /// app's `openURL` override resolves to the in-app recipe detail.
    let recipeBaseURL: String
    /// DUT-104 — called once when the flow reaches "Done", with the cook to log.
    let onLogCook: ((CookLogEntry) -> Void)?

    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    /// 0 = intro; 1...steps.count = each coached step; steps.count + 1 = celebration.
    @State private var index = 0
    /// Drives the live bake timer offered at the *cook* stage (DUT-100).
    @State var timerEngine = CookTimerEngine()
    @State var showingHeatCoach = false
    /// Items the cook has ticked off the *gather* checklist.
    @State var checkedItems: Set<String> = []
    @State var cookPhotoItem: PhotosPickerItem?
    @State var cookPhoto: Image?
    @State var showingCamera = false
    /// Guards against double-logging if the user taps Done more than once.
    @State private var hasLoggedCook = false

    public init(
        cookout: GuidedCookout = .firstCookout,
        recipeBaseURL: String = "https://www.dutchovendaddy.com",
        onLogCook: ((CookLogEntry) -> Void)? = nil
    ) {
        self.cookout = cookout
        self.recipeBaseURL = recipeBaseURL
        self.onLogCook = onLogCook
    }

    var lastIndex: Int { cookout.steps.count + 1 }

    var shareCaption: String {
        "I made my first \(cookout.dishTitle) with @dutchovendaddy! 🔥 #DutchOvenDaddy"
    }

    public var body: some View {
        VStack(spacing: DODSpacing.lg) {
            ScrollView {
                screen
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DODSpacing.md)
            }
            controls
        }
        .padding(DODSpacing.lg)
        .background(DODColor.surface)
        .animation(.easeInOut(duration: 0.25), value: index)
        .task { await runTimerTick() }
        .sheet(isPresented: $showingHeatCoach) {
            NavigationStack { HeatCoachView() }
        }
        .sheet(isPresented: $showingCamera) {
            #if canImport(UIKit)
            CameraPicker { image in
                showingCamera = false
                if let image { cookPhoto = Image(uiImage: image) }
            }
            .ignoresSafeArea()
            #else
            EmptyView()
            #endif
        }
        .onChange(of: cookPhotoItem) { _, newItem in
            Task { await loadPhoto(newItem) }
        }
    }

    /// Advances the timer engine ~1×/s while the flow is on screen so the bake
    /// countdown ticks down and finishes. A cheap no-op when no timer runs.
    private func runTimerTick() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            timerEngine.refresh()
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        #if canImport(UIKit)
        if let uiImage = UIImage(data: data) {
            cookPhoto = Image(uiImage: uiImage)
        }
        #endif
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
            switch step.stage {
            case .gather:
                gatherChecklist
            case .fire:
                coalsCard
                heatCoachButton
            case .cook:
                rotationReminder
                cookTimerCard
                recipeButton
            case .celebrate:
                EmptyView()
            }
        }
        .frame(maxWidth: 520)
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
            shareSection
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
                    logCookIfNeeded()
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

    /// Log the completed cook exactly once (DUT-104) — fired on "Done" so the
    /// journal records "I made the lasagna today", feeding streaks/stats.
    private func logCookIfNeeded() {
        guard !hasLoggedCook else { return }
        hasLoggedCook = true
        onLogCook?(
            CookLogEntry(
                id: UUID(),
                recipeID: cookout.recipeID,
                recipeTitle: cookout.dishTitle,
                cookedAt: .now
            )
        )
    }

    func stageIcon(_ stage: GuidedCookout.Stage) -> String {
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
