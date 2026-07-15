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

    // MARK: Swipe paging (DUT-197)

    /// Advance/retreat the flow on a horizontally-dominant swipe past a ~50pt
    /// threshold; vertical scrolls (handled by the ScrollView) are left alone.
    func handleSwipe(_ translation: CGSize) {
        let deltaX = translation.width
        guard abs(deltaX) > abs(translation.height), abs(deltaX) > 50 else { return }
        if deltaX < 0, index < lastIndex {
            withAnimation(.easeInOut(duration: 0.25)) { index += 1 }
        } else if deltaX > 0, index > 0 {
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
                // DUT-422 — re-identify per message so a new error text drives a
                // fresh appearance + a restarted auto-dismiss timer (mirrors
                // SettingsView / DUT-362 / DUT-419).
                .id(message)
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
        // DUT — a light selection tick when a row is checked/unchecked, matching
        // the haptic every sibling checklist in the app already gives.
        .sensoryFeedback(.selection, trigger: checkedItems)
    }

    private func checklistSection(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text(title)
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
            // DUT-374 — key by section + index, not the ingredient string, so a
            // recipe that lists the same item twice (e.g. two "1 cup water" lines)
            // gets independent ticks instead of toggling every duplicate together.
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                checklistRow(item, key: "\(title)#\(index)")
            }
        }
    }

    private func checklistRow(_ item: String, key: String) -> some View {
        let isChecked = checkedItems.contains(key)
        return Button {
            if isChecked { checkedItems.remove(key) } else { checkedItems.insert(key) }
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
            // DUT-291: give each row a full 44pt tap target (a single-line row is
            // ~20pt) so the whole width — not just the glyph + text — toggles it.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // DUT-402: expose the checked state to VoiceOver (mirrors IngredientCheckRow).
        .accessibilityValue(isChecked ? "checked" : "unchecked")
        .accessibilityAddTraits(isChecked ? [.isSelected] : [])
    }

    // The *fire* step (embedded ``CoalAnswerCard`` + the Heat Coach CTA) lives in
    // `FirstCookoutView+Fire.swift` (DUT — the inline coal card pushed this file
    // over the `file_length` cap; extension members in a sibling file don't count).

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
        // DUT-495: scope lookups to this rung's recipeID (shared engine, DUT-484).
        if let active = timerEngine.timers.first(where: {
            $0.isRunning && $0.recipeID == cookout.recipeID
        }) {
            VStack(spacing: DODSpacing.xxs) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(formatRemaining(active.remaining(at: context.date)))
                        .dodFont(DODType.displayMedium)
                        .monospacedDigit()
                        .foregroundStyle(DODColor.burntOrange)
                        .accessibilityLabel(  // DUT-401 — spell "5:03" out for VoiceOver
                            bakeCountdownLabel(active.remaining(at: context.date))
                        )
                }
                Text(bakeStepAwayText)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                Button("Cancel Timer") {
                    timerEngine.cancel(active.id)
                    Task { await notifier.cancelBakeDone(for: active.recipeID) }  // DUT-547: this rung only.
                }
                .foregroundStyle(DODColor.labelSecondary)
                .frame(minHeight: 44)  // DUT-291: 44pt tap target
                .contentShape(Rectangle())
            }
            .padding(.top, DODSpacing.xs)
        } else if timerEngine.timers.contains(where: {
            $0.state == .finished && $0.recipeID == cookout.recipeID
        }) {
            VStack(spacing: DODSpacing.xxs) {
                Text("Timer's Up!")
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.burntOrange)
                Text(goCheckText)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                // DUT-255 — clear the finished state so the card falls back to the
                // else branch (the start button) and the cook can time the rest of
                // the bake. Scoped to THIS rung's recipeID so a shared-engine
                // sibling rung's timer (DUT-484) is left untouched.
                Button("Start Another Timer") {
                    timerEngine.clearFinished(for: cookout.recipeID)
                }
                .foregroundStyle(DODColor.labelSecondary)
                .frame(minHeight: 44)  // DUT-291: 44pt tap target
                .contentShape(Rectangle())
                .accessibilityIdentifier("first-cookout-clear-timer")
            }
            .padding(.top, DODSpacing.xs)
            // DUT — crossfade the countdown→"Timer's Up!" swap (previously an
            // un-animated jump); the animation transaction is driven + reduce-
            // motion-gated at the `cookTimerCard` call site in `stepScreen`.
            .transition(.opacity)
            // DUT-401 — announce the silent finished swap (DUT-297 covers only
            // the backgrounded case). SwiftUI API → macOS test slice compiles.
            .onAppear {
                AccessibilityNotification.Announcement("Timer's up! \(goCheckText)").post()
            }
        } else {
            Button("Start the \(cookout.bakeMinutes)-Minute Bake Timer") {
                let duration = Double(cookout.bakeMinutes) * 60
                didStartBake = true  // DUT-626 — mark real cook progress for the onDisappear log gate.
                timerEngine.start(label: bakeTimerLabel, duration: duration, recipeID: cookout.recipeID)
                // DUT-297: schedule the deadline alert so "you can step away" holds
                // backgrounded (tick loop is foreground-only). DUT-547: keyed per rung.
                Task { await notifier.scheduleBakeDone(after: duration, recipeID: cookout.recipeID) }
            }
            .dodProminentButton()
            .tint(DODColor.burntOrange)
            .padding(.top, DODSpacing.xs)
        }
    }

    // `recipeButton` (DUT-246 — awaitable open, sheet stays up until the
    // resolve lands) lives in `FirstCookoutView+RecipeLink.swift`.

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
                    // DUT-232 — VoiceOver otherwise lands on a bare "image" element.
                    .accessibilityLabel(Text(cookPhotoAccessibilityLabel))
                ShareLink(
                    item: photo,
                    subject: Text(shareSubject),  // DUT-211 — first-rung-aware, not always "first"
                    message: Text(shareCaption),
                    preview: SharePreview(sharePreviewTitle, image: photo)
                ) {
                    Label("Share Your Cook", systemImage: "square.and.arrow.up")
                }
                .dodProminentButton()
                .tint(DODColor.burntOrange)
                // DUT-203 — clear ALL photo state so a Retake-then-Done can't save
                // the discarded photo, and re-picking the same asset re-fires onChange.
                Button("Retake or Choose Another") {
                    cookPhoto = nil
                    cookPhotoData = nil
                    cookPhotoItem = nil
                }
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .frame(minHeight: 44)  // DUT-291: 44pt tap target
                .contentShape(Rectangle())
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
                Label("Take a Photo", systemImage: "camera.fill")
            }
            .dodProminentButton()
            .tint(DODColor.burntOrange)
        }
        #endif
        PhotosPicker(selection: $cookPhotoItem, matching: .images) {
            Label("Choose from Library", systemImage: "photo.on.rectangle")
        }
        .dodBorderedButton()
        .tint(DODColor.burntOrange)
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
                    .frame(minWidth: 44, minHeight: 44)  // DUT-291: 44pt tap target
                    .contentShape(Rectangle())
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
