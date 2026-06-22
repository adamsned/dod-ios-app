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
    }

    // MARK: Fire — coal count + Heat Coach

    /// The live coal recommendation for the dish (DUT-128).
    var coalsCard: some View {
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
                "for a \(cookout.ovenDiameterInches)-inch oven at \(cookout.ovenTempF)°F, "
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

    /// Open the full Heat Coach to dial coals in by size / conditions.
    var heatCoachButton: some View {
        Button {
            showingHeatCoach = true
        } label: {
            Label("Open the Heat Coach", systemImage: "thermometer.sun.fill")
        }
        .buttonStyle(.bordered)
        .tint(DODColor.burntOrange)
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
            RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
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
                Button("Cancel timer") { timerEngine.cancel(active.id) }
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
                timerEngine.start(
                    label: bakeTimerLabel,
                    duration: Double(cookout.bakeMinutes) * 60
                )
            }
            .buttonStyle(.borderedProminent)
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
        .buttonStyle(.borderedProminent)
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
                    .clipShape(RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous))
                ShareLink(
                    item: photo,
                    subject: Text("My first Dutch oven cook"),
                    message: Text(shareCaption),
                    preview: SharePreview(sharePreviewTitle, image: photo)
                ) {
                    Label("Share / Post, tags Dutch Oven Daddy", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
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
            .buttonStyle(.borderedProminent)
            .tint(DODColor.burntOrange)
        }
        #endif
        PhotosPicker(selection: $cookPhotoItem, matching: .images) {
            Label("Choose from library", systemImage: "photo.on.rectangle")
        }
        .buttonStyle(.bordered)
        .tint(DODColor.burntOrange)
    }

    func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
