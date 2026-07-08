import DODDesignSystem
import DODPersistence
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
    /// CL-267 — returns to the roadmap (the `CookChooserFlow` path) instead of
    /// dismissing the whole sheet. `nil` when presented standalone (no roadmap to
    /// return to); the chooser sets it so the recipe flow has a "back to the path"
    /// affordance alongside the close (X).
    let onBack: (() -> Void)?
    /// DUT-297 — schedules the "bake is done" notification so the guided timer
    /// reaches the cook even when they "step away" (background the app).
    let notifier: any BakeTimerNotifying
    /// DUT-548 — the set of rung recipeIDs already logged, OWNED by the host
    /// (`CookChooserFlow`) so it survives a "Back to the path" → re-enter cycle
    /// (which tears this view down + rebuilds it with a fresh `hasLoggedCook`).
    /// Aligns with DUT-484/547's per-recipe keying on the shared engine: the log
    /// guard is now keyed by `cookout.recipeID`, not a per-view boolean. `nil`
    /// in unwired hosts (previews / standalone) → the legacy
    /// per-view `hasLoggedCook` guard.
    @Binding var loggedRecipeIDs: Set<Int>
    /// DUT-209 — the off-main celebration-photo writer. Injected so the atomic
    /// full-resolution JPEG write no longer hitches the main thread right before
    /// "Done" dismisses, and so tests can assert it runs off-main.
    let photoWriter: any CookPhotoWriting

    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    /// DUT-246 — the app shell's awaitable recipe-link opener. When present,
    /// "Open the recipe" keeps this sheet up until the resolve completes and
    /// dismisses only if in-app navigation actually happened (no more blank
    /// dead interval while the resolve is in flight). `nil` in unwired hosts
    /// (previews/tests) → the legacy openURL + dismiss path.
    @Environment(\.recipeLinkOpener) var recipeLinkOpener
    /// DUT — gates the guided-bake "Timer's Up!" crossfade so a Reduce Motion
    /// cook gets an instant swap. Read here (stored on the struct) so the
    /// `cookTimerCard` builder in `+Stages.swift` can reach it across the extension.
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    /// 0 = intro; 1...steps.count = each coached step; steps.count + 1 = celebration.
    /// Internal (not private) so the swipe handler in `+Stages.swift` can page it.
    @State var index = 0
    /// DUT-246 — true while the "Open the recipe" resolve is in flight; drives
    /// the button's busy state so the sheet visibly waits instead of
    /// dismissing into a blank gap. Internal for `+RecipeLink.swift`.
    @State var isOpeningRecipe = false
    /// Drives the live bake timer offered at the *cook* stage (DUT-100).
    /// DUT-484: injectable so the guided-path host (`CookChooserFlow`) can OWN
    /// the engine and keep a running bake alive across a "Back to the path" →
    /// re-enter cycle (which tears this view down + rebuilds it). When not
    /// injected (previews / standalone) the view owns its own.
    @State var timerEngine: CookTimerEngine
    @State var showingHeatCoach = false
    /// DUT-626 — flips true the moment the cook actually starts the bake timer
    /// for this rung, so the `.onDisappear` safety-net logs a cook only on real
    /// progress (not merely paging to the celebration). Internal so the Start
    /// action in `+Stages.swift` can set it.
    @State var didStartBake = false
    /// DUT — a monotonic tick bumped once each time THIS rung's guided bake timer
    /// finishes (in the `onFinished` hook), so a `.sensoryFeedback(.success)` on
    /// the flow buzzes at "Timer's Up!" just like Cook Mode's completion tick.
    /// Internal so the `onFinished` closure wired in `body`'s `.task` can bump it.
    @State var bakeTimerFinishTick = 0
    /// Items the cook has ticked off the *gather* checklist.
    @State var checkedItems: Set<String> = []
    @State var cookPhotoItem: PhotosPickerItem?
    @State var cookPhoto: Image?
    /// Raw JPEG bytes of the captured photo — saved to the journal on "Done".
    @State var cookPhotoData: Data?
    @State var showingCamera = false
    /// Guards against double-logging if the user taps Done more than once.
    /// Internal (not private) so the `logCookIfNeeded` logic moved to
    /// `FirstCookoutView+Logging.swift` (file-length relief) can read it.
    @State var hasLoggedCook = false
    /// DUT-312 — humane copy when the celebration photo fails to persist to
    /// disk. Surfaced via the snackbar overlay so the hero first-cook photo
    /// failure isn't silently swallowed; the cook itself still logs. Internal
    /// (not private) so the snackbar overlay in `+Stages.swift` can read it.
    @State var photoSaveError: String?
    /// DUT-324 — an optional short written reflection the cook can jot on the
    /// celebration screen ("how did it go?"), saved as the logged cook's note.
    /// Internal (not private) so the `reflectionField` view-builder in
    /// `+Stages.swift` can bind to it.
    @State var reflection: String = ""

    public init(
        cookout: GuidedCookout = .firstCookout,
        recipeBaseURL: String = "https://www.dutchovendaddy.com",
        onLogCook: ((CookLogEntry) -> Void)? = nil,
        onBack: (() -> Void)? = nil,
        notifier: any BakeTimerNotifying = SystemBakeTimerNotifier(),
        timerEngine: CookTimerEngine? = nil,
        loggedRecipeIDs: Binding<Set<Int>>? = nil,
        photoWriter: any CookPhotoWriting = SystemCookPhotoWriter()
    ) {
        self.cookout = cookout
        self.recipeBaseURL = recipeBaseURL
        self.onLogCook = onLogCook
        self.onBack = onBack
        self.notifier = notifier
        self.photoWriter = photoWriter
        // DUT-548: adopt the host-owned "already logged" set when provided (so a
        // logged cook survives a Back → re-enter cycle); otherwise a throwaway
        // constant binding — the per-view `hasLoggedCook` still guards a single
        // lifecycle for the unwired hosts (previews / standalone) that can't
        // re-enter the same rung anyway.
        _loggedRecipeIDs = loggedRecipeIDs ?? .constant([])
        // DUT-484: adopt the host-owned engine when provided (so a bake timer
        // survives a Back → re-enter cycle); otherwise own a fresh one. On
        // re-creation `State(initialValue:)` re-adopts the SAME injected
        // instance from the host's surviving state, so the countdown persists
        // and the cook step shows it rather than re-offering Start (which would
        // re-schedule the bake-done alert to a wrong, full-length deadline).
        _timerEngine = State(initialValue: timerEngine ?? CookTimerEngine())
    }

    var lastIndex: Int { cookout.steps.count + 1 }

    /// DUT-626 — true when the cook has ACTUALLY engaged the bake for this rung:
    /// either they tapped Start this lifecycle (`didStartBake`) or the shared
    /// engine still holds a timer for this rung (survives a "Back to the path" →
    /// re-enter cycle, DUT-484). Gates the `.onDisappear` cook-log safety net so
    /// paging to the celebration without cooking never logs a phantom cook.
    var hasBakeProgress: Bool {
        didStartBake || timerEngine.timers.contains { $0.recipeID == cookout.recipeID }
    }

    // `shareCaption` moved to `FirstCookoutView+TimerFormat.swift` (DUT-484 — the
    // injectable-engine init pushed this struct body over the type_body_length
    // cap; extension members in a sibling file don't count).

    // DUT-192 campfire-aware copy helpers + DUT-197 swipe handler live in
    // FirstCookoutView+Stages.swift (keeps this struct body under the cap).

    public var body: some View {
        VStack(spacing: DODSpacing.lg) {
            ScrollView {
                screen
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DODSpacing.md)
            }
            // DUT-197 — additive horizontal swipe paging. Attached as a
            // `.simultaneousGesture` so it rides alongside (never replaces) the
            // ScrollView's own vertical scroll. We only act on an *ended* drag
            // that is horizontally dominant (`abs(width) > abs(height)`) and past
            // a ~50pt threshold, so a normal vertical scroll is left untouched.
            // Swipe left → forward, swipe right → back; the Next/Back buttons in
            // `controls` keep working unchanged.
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { handleSwipe($0.translation) }
            )
            controls
        }
        // CL-267 / DUT-188 — pinned corner controls (outside the ScrollView so
        // they never scroll away): "back to the path" (top-leading) returns to the
        // roadmap; the X (top-trailing) closes the whole sheet. Both live in
        // `+Stages.swift` to keep this struct body under the SwiftLint cap.
        .overlay(alignment: .topLeading) { backToPathButton }
        .overlay(alignment: .topTrailing) { closeButton }
        // DUT-312 — surface a photo-save failure to the hero cook (instead of
        // swallowing it) without blocking the logged cook itself.
        .overlay(alignment: .bottom) { photoSaveErrorSnackbar }
        .padding(DODSpacing.lg)
        .background(DODColor.surface)
        .animation(.easeInOut(duration: 0.25), value: index)
        // DUT — a `.success` haptic the moment this rung's guided bake timer hits
        // zero (mirrors CookModeView's `timerCompletionTick`); the tick only
        // increments, so it never mis-fires on clear/restart.
        .sensoryFeedback(.success, trigger: bakeTimerFinishTick)
        .task {
            // DUT-297: if the bake finishes while we're on screen, drop the
            // pending notification — the cook is already looking at "Timer's up!".
            // DUT-547: cancel only the FINISHED timer's own per-recipe alert (via
            // its `recipeID`), never a sibling rung's still-pending bake — the
            // shared engine (DUT-484) can have another rung's bake queued.
            timerEngine.onFinished = { timer in
                Task { await notifier.cancelBakeDone(for: timer.recipeID) }
                // DUT — buzz a `.success` when THIS rung's bake finishes (the
                // guided timer was previously silent, unlike Cook Mode). Scoped
                // by recipeID so a shared-engine sibling rung (DUT-484) can't
                // trigger this flow's haptic.
                if timer.recipeID == cookout.recipeID { bakeTimerFinishTick += 1 }
            }
            await runTimerTick()
        }
        .sheet(isPresented: $showingHeatCoach) {
            NavigationStack { HeatCoachView() }
        }
        .sheet(isPresented: $showingCamera) {
            #if canImport(UIKit)
            CameraPicker { image in
                showingCamera = false
                if let image {
                    cookPhoto = Image(uiImage: image)
                    cookPhotoData = image.jpegData(compressionQuality: 0.85)
                }
            }
            .ignoresSafeArea()
            #else
            EmptyView()
            #endif
        }
        .onChange(of: cookPhotoItem) { _, newItem in
            Task { await loadPhoto(newItem) }
        }
        // DUT-198 — safety net: if the cook reached the celebration (i.e. finished
        // the cook) but left via the X / swipe-down instead of tapping "Done", log
        // it anyway. `logCookIfNeeded()` is guarded by `hasLoggedCook`, so the
        // explicit "Done" tap and this path never double-log.
        // DUT-626 — additionally gate on ACTUAL cook progress (the bake timer for
        // this rung was started or finished), not merely reaching the last page
        // index. Paging to the celebration WITHOUT ever cooking (e.g. swiping
        // through) must not log a phantom cook via this safety net. The explicit
        // "Done" tap remains an intentional log and is unaffected.
        .onDisappear {
            if index >= lastIndex, hasBakeProgress { logCookIfNeeded() }
        }
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
                .accessibilityHidden(true)
            Text(cookout.introEyebrow)  // DUT-207: per-rung header (not always "First")
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
                .accessibilityHidden(true)
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
                heatCoachCallToAction
                coalStartingPointNote
            case .cook:
                rotationReminder
                cookTimerCard
                    // DUT — animate the countdown→"Timer's Up!" swap (keyed on the
                    // finish tick so only that transition fires), gated on Reduce
                    // Motion so an accessibility cook gets an instant swap.
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.25),
                        value: bakeTimerFinishTick
                    )
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
                .accessibilityHidden(true)
            Text("You Did It.")
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
            Text(cookout.celebrationMessage)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .multilineTextAlignment(.center)
            shareSection
            reflectionField
            Text(cookout.nextStepPrompt)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, DODSpacing.xs)
        }
        .frame(maxWidth: 520)
    }

    // MARK: - Controls

    /// The paged-flow footer (DUT-324): a centered primary CTA on top, with the
    /// page dots centered below and a leading "Back" button shown only past the
    /// intro (`index > 0`).
    private var controls: some View {
        VStack(spacing: DODSpacing.sm) {
            primaryButton
            ZStack {
                HStack {
                    if index > 0 {
                        Button("Back") { index -= 1 }
                            .foregroundStyle(DODColor.labelSecondary)
                    }
                    Spacer()
                }
                progressDots
            }
        }
    }

    /// The centered primary call to action ("Let's Cook" / "Next" / "Done").
    /// Wrapped between spacers so it centers rather than stretching full-bleed.
    private var primaryButton: some View {
        HStack {
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
            Spacer()
        }
    }

    private var primaryButtonTitle: String {
        if index == 0 { return "Let's Cook" }
        if index >= lastIndex { return "Done" }
        return "Next"
    }
}

#Preview("Intro") {
    FirstCookoutView()
}
