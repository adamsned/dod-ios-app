import DODDesignSystem
import DODSupport
import PhotosUI
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// The per-stage views for ``FirstCookoutView`` (US-53 / AC-53.2 / DUT-183),
/// extracted here so the main flow file stays under the SwiftLint length caps.
extension FirstCookoutView {

    // MARK: Campfire-aware copy (DUT-192) — dish-agnostic phrasing for the
    // capstone; "Take It to the Campfire" only reads well as a title.

    var sharePreviewTitle: String {
        cookout.isCampfire ? "My campfire cook" : "My \(cookout.dishTitle)"
    }

    var recipeLinkLabel: String {
        cookout.isCampfire ? "Open the heat & coals guide" : "Open the \(cookout.dishTitle) recipe"
    }

    var bakeTimerLabel: String {
        cookout.isCampfire ? "Campfire cook" : "\(cookout.dishTitle) bake"
    }

    var bakeStepAwayText: String {
        cookout.isCampfire
            ? "Your cook is going, you can step away"
            : "\(cookout.dishTitle) bake, you can step away"
    }

    var goCheckText: String {
        cookout.isCampfire ? "Go check your Dutch oven." : "Go check your \(cookout.dishTitle)."
    }

    // MARK: Swipe paging (DUT-197)

    /// Advance/retreat the flow on a horizontally-dominant swipe past a ~50pt
    /// threshold; vertical scrolls (handled by the ScrollView) are left alone.
    func handleSwipe(_ translation: CGSize) {
        let dx = translation.width
        guard abs(dx) > abs(translation.height), abs(dx) > 50 else { return }
        if dx < 0, index < lastIndex {
            withAnimation(.easeInOut(duration: 0.25)) { index += 1 }
        } else if dx > 0, index > 0 {
            withAnimation(.easeInOut(duration: 0.25)) { index -= 1 }
        }
    }

    // MARK: Photo-save error (DUT-312)

    /// Bottom snackbar shown when the celebration photo couldn't be saved to
    /// disk on the hero first cook. Auto-dismisses on tap; mirrors the
    /// `SettingsView` snackbar overlay. Lives here (not the main flow file) to
    /// keep `FirstCookoutView`'s struct body under the SwiftLint length cap.
    @ViewBuilder var photoSaveErrorSnackbar: some View {
        if let message = photoSaveError {
            Snackbar(message: message)
                .padding(.bottom, DODSpacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture { photoSaveError = nil }
                .task {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    photoSaveError = nil
                }
                .accessibilityIdentifier("first-cookout-photo-error")
        }
    }

    // MARK: Gather — gear + ingredients checklist

    /// A tappable gear + ingredients checklist so the cook can round everything
    /// up and tick it off (the "here's exactly what you need" beat).
    var gatherChecklist: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            checklistSection("Gear", items: cookout.gear)
            checklistSection("Ingredients", items: cookout.ingredients)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DODSpacing.xs)
    }

    private func checklistSection(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text(title)
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
            ForEach(items, id: \.self) { item in
                checklistRow(item)
            }
        }
    }

    private func checklistRow(_ item: String) -> some View {
        let isChecked = checkedItems.contains(item)
        return Button {
            if isChecked { checkedItems.remove(item) } else { checkedItems.insert(item) }
        } label: {
            HStack(spacing: DODSpacing.sm) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? DODColor.burntOrange : DODColor.labelSecondary)
                Text(item)
                    .dodFont(DODType.body)
                    .strikethrough(isChecked)
                    .foregroundStyle(isChecked ? DODColor.labelSecondary : DODColor.label)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        // DUT-402: expose the checked state to VoiceOver (mirrors IngredientCheckRow).
        .accessibilityValue(isChecked ? "checked" : "unchecked")
        .accessibilityAddTraits(isChecked ? [.isSelected] : [])
    }

    // MARK: Fire — Heat Coach first, then a rough starting point (DUT-239)

    /// DUT-239: the fire step **leads with the Heat Coach**. Coals are read by
    /// feel for the cook's own conditions (wind, weather, charcoal brand/size,
    /// oven size) — a single prescribed number on the scariest step can sink a
    /// beginner's first cook, the opposite of the guaranteed-win promise. So the
    /// Heat Coach is the prominent CTA, not a button demoted below a hard count.
    var heatCoachCallToAction: some View {
        VStack(spacing: DODSpacing.xs) {
            Text(
                "Every fire is different — wind, weather, and your charcoal all change "
                    + "the count. Read the coals by feel instead of trusting one number."
            )
            .dodFont(DODType.body)
            .foregroundStyle(DODColor.labelSecondary)
            .multilineTextAlignment(.center)
            Button {
                showingHeatCoach = true
            } label: {
                Label("Open the Heat Coach", systemImage: "thermometer.sun.fill")
                    .frame(maxWidth: .infinity)
            }
            .dodProminentButton()
            .tint(DODColor.burntOrange)
        }
        .padding(.top, DODSpacing.xs)
    }

    /// DUT-239: a *rough* starting point only — a range, framed as "dial it in
    /// with the Heat Coach," never a hard "X coals" answer. De-emphasized below
    /// the Heat Coach CTA so the beginner reaches for the coach, not the number.
    var coalStartingPointNote: some View {
        let coals = CharcoalRecipeConverter.recommend(
            ovenTempF: cookout.ovenTempF,
            ovenDiameterInches: cookout.ovenDiameterInches,
            task: .bake
        )
        // A loose ±2 range so it never reads as a precise rule.
        let low = max(coals.totalBriquettes - 2, 0)
        let high = coals.totalBriquettes + 2
        return Text(
            "Rough starting point: about \(low)-\(high) coals for a "
                + "\(cookout.ovenDiameterInches)-inch oven — then dial it in for your "
                + "conditions with the Heat Coach."
        )
        .dodFont(DODType.caption)
        .foregroundStyle(DODColor.labelSecondary)
        .multilineTextAlignment(.center)
        .padding(.top, DODSpacing.xxs)
    }

    // MARK: Cook — rotation reminder + timer + recipe

    /// The lid-rotation reminder for even baking.
    var rotationReminder: some View {
        HStack(spacing: DODSpacing.xs) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(DODColor.burntOrange)
            Text(
                "Rotate the oven and the lid a quarter-turn (90°) every 15 minutes so it "
                    + "bakes evenly and no side burns."
            )
            .dodFont(DODType.caption)
            .foregroundStyle(DODColor.label)
        }
        .padding(DODSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .padding(.top, DODSpacing.xs)
    }

    /// The live bake timer (DUT-100): not started → counting down → done.
    @ViewBuilder var cookTimerCard: some View {
        if let active = timerEngine.timers.first(where: { $0.isRunning }) {
            VStack(spacing: DODSpacing.xxs) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(formatRemaining(active.remaining(at: context.date)))
                        .dodFont(DODType.displayMedium)
                        .monospacedDigit()
                        .foregroundStyle(DODColor.burntOrange)
                }
                Text(bakeStepAwayText)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                Button("Cancel timer") {
                    timerEngine.cancel(active.id)
                    Task { await notifier.cancelBakeDone() }
                }
                .foregroundStyle(DODColor.labelSecondary)
            }
            .padding(.top, DODSpacing.xs)
        } else if timerEngine.timers.contains(where: { $0.state == .finished }) {
            VStack(spacing: DODSpacing.xxs) {
                Text("Timer's up!")
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.burntOrange)
                Text(goCheckText)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
            }
            .padding(.top, DODSpacing.xs)
        } else {
            Button("Start the \(cookout.bakeMinutes)-minute bake timer") {
                let duration = Double(cookout.bakeMinutes) * 60
                timerEngine.start(label: bakeTimerLabel, duration: duration)
                // DUT-297: schedule the deadline alert so "you can step away" holds
                // even backgrounded (the tick loop is foreground-only).
                Task { await notifier.scheduleBakeDone(after: duration) }
            }
            .dodProminentButton()
            .tint(DODColor.burntOrange)
            .padding(.top, DODSpacing.xs)
        }
    }

    /// Open the recipe. The app's `openURL` override resolves a DOD recipe URL
    /// to the in-app recipe detail; dismiss this sheet so that navigation is
    /// actually visible (it was opening behind the sheet).
    var recipeButton: some View {
        Button(recipeLinkLabel) {
            if let url = URL(string: "\(recipeBaseURL)/\(cookout.recipeSlug)/") {
                openURL(url)
                dismiss()
            }
        }
        .dodProminentButton()
        .tint(DODColor.burntOrange)
        .padding(.top, DODSpacing.xs)
    }

    // MARK: Celebrate — photo + share to social

    /// Snap/pick a photo of the finished dish and share it to social, tagging
    /// Dutch Oven Daddy. The word-of-mouth moment: the gathering, shared.
    @ViewBuilder var shareSection: some View {
        VStack(spacing: DODSpacing.sm) {
            if let photo = cookPhoto {
                photo
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
                ShareLink(
                    item: photo,
                    subject: Text("My first Dutch oven cook"),
                    message: Text(shareCaption),
                    preview: SharePreview(sharePreviewTitle, image: photo)
                ) {
                    Label("Share / Post, tags Dutch Oven Daddy", systemImage: "square.and.arrow.up")
                }
                .dodProminentButton()
                .tint(DODColor.burntOrange)
                // DUT-203 — clear ALL photo state so a Retake-then-Done can't save
                // the discarded photo, and re-picking the same asset re-fires onChange.
                Button("Retake or choose another") {
                    cookPhoto = nil
                    cookPhotoData = nil
                    cookPhotoItem = nil
                }
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            } else {
                photoSourceButtons
            }
            Text("Tag @dutchovendaddy + #DutchOvenDaddy so Ned can see it!")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DODSpacing.xs)
    }

    /// Primary "Take a photo" (camera, where available) + "Choose from library".
    /// The camera affordance is hidden where there's no camera (Simulator / macOS).
    @ViewBuilder private var photoSourceButtons: some View {
        #if canImport(UIKit)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            Button {
                showingCamera = true
            } label: {
                Label("Take a photo", systemImage: "camera.fill")
            }
            .dodProminentButton()
            .tint(DODColor.burntOrange)
        }
        #endif
        PhotosPicker(selection: $cookPhotoItem, matching: .images) {
            Label("Choose from library", systemImage: "photo.on.rectangle")
        }
        .dodBorderedButton()
        .tint(DODColor.burntOrange)
    }

    func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// DUT-324 — a short, optional written reflection on the celebration screen,
    /// saved as the logged cook's note. Mirrors `CookJournalEntryView`'s editor:
    /// a `TextEditor` on a `surfaceElevated` rounded card, with a gentle
    /// placeholder overlaid while empty.
    var reflectionField: some View {
        ZStack(alignment: .topLeading) {
            if reflection.isEmpty {
                Text("Add a note about this cook (optional).")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 9)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $reflection)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 96)
                .accessibilityIdentifier("first-cookout-reflection")
        }
        .padding(DODSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .padding(.top, DODSpacing.xs)
    }

    /// The centered page-progress dots for the paged flow footer (`controls`).
    var progressDots: some View {
        HStack(spacing: DODSpacing.xxs) {
            ForEach(0...lastIndex, id: \.self) { dot in
                Circle()
                    .fill(dot == index ? DODColor.burntOrange : DODColor.labelSecondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityLabel("Step \(index + 1) of \(lastIndex + 1)")
    }

    // MARK: - Pinned corner controls

    /// CL-267 — "back to the path" chevron (top-leading): returns to the roadmap
    /// (`CookChooserFlow`) via `onBack` instead of closing the whole sheet, so a
    /// picked recipe isn't a dead end. Hidden when there's no roadmap to return to.
    @ViewBuilder var backToPathButton: some View {
        if let onBack {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.backward.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            .accessibilityLabel("Back to the path")
            .accessibilityIdentifier("first-cookout-back")
        }
    }

    /// DUT-188 — explicit close (X), top-trailing: dismisses the whole sheet (the
    /// swipe-down companion). Pinned outside the ScrollView so it never scrolls.
    var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(DODColor.labelSecondary)
                .frame(minWidth: 44, minHeight: 44)  // DUT-291: 44pt tap target
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Close")
        .accessibilityIdentifier("first-cookout-close")
    }
}
