import DODDesignSystem
import DODDomain
import DODPersistence
import SwiftUI

#if os(iOS) && canImport(PencilKit)
import PencilKit
#endif

/// The Instructions block of the recipe reading view: header (+ iPad-only
/// annotate toggle) → Cook Mode CTA → numbered steps, with an optional
/// PencilKit canvas overlaid on the steps for handwritten annotation
/// (iPad + Apple Pencil, v2).
///
/// Extracted from `RecipeDetailView+Sections.swift` so this View can own the
/// `@State` the toggle (in the header) and the canvas (over the steps) share —
/// a computed section `var` in an extension can't hold state. On iPhone /
/// compact width the annotate affordance and canvas never render, so the
/// section stays byte-identical to before.
struct InstructionsSectionView: View {

    let instructions: [RecipeInstruction]
    /// Display text per step (temperature-converted upstream; stored text
    /// untouched — see `RecipeDetailView+Sections.swift`).
    let displayText: (RecipeInstruction) -> String
    let horizontalSizeClass: UserInterfaceSizeClass?
    /// Cook Mode CTA tap seam (records intent + presents the cover upstream).
    let onCookMode: () -> Void
    /// Load the saved annotation for this recipe (`nil` when none / not iPad).
    let load: () async -> RecipeAnnotationRecord?
    /// Persist this recipe's annotation (best-effort).
    let save: (RecipeAnnotationRecord) async -> Void

    @State private var isAnnotating = false
    @State private var canvasWidth: CGFloat = 0

    #if os(iOS) && canImport(PencilKit)
    @State private var drawing = PKDrawing()
    @State private var saveTask: Task<Void, Never>?
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            header
            CookNowCTA(onTap: onCookMode)
            stepsContent
        }
        .padding(.horizontal, DODSpacing.md)
        #if os(iOS) && canImport(PencilKit)
        .task { await loadAnnotation() }
        .onChange(of: drawing.dataRepresentation()) { _, _ in scheduleSave() }
        .onChange(of: isAnnotating) { _, active in if !active { saveNow() } }
        .onDisappear { saveNow() }
        #endif
    }

    // MARK: - Header + toggle

    private var header: some View {
        HStack(spacing: DODSpacing.sm) {
            Text("Instructions")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
            #if os(iOS) && canImport(PencilKit)
            if showsAnnotateAffordance {
                Spacer(minLength: DODSpacing.sm)
                annotateToggle
            }
            #endif
        }
        // DUT-673 — scroll anchor stays on the header row so "Jump to
        // Instructions" lands with "Instructions" at the top of the viewport.
        .id(RecipeDetailView.SectionAnchor.instructions)
    }

    @ViewBuilder private var stepsContent: some View {
        let steps = VStack(alignment: .leading, spacing: DODSpacing.md) {
            ForEach(instructions) { step in
                InstructionStepView(step: step, displayText: displayText(step))
            }
        }
        #if os(iOS) && canImport(PencilKit)
        steps.overlay { annotationOverlay }
        #else
        steps
        #endif
    }

    // MARK: - iPad annotation (Apple Pencil)

    #if os(iOS) && canImport(PencilKit)
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private var showsAnnotateAffordance: Bool {
        shouldShowAnnotateAffordance(
            isRegularWidth: horizontalSizeClass == .regular,
            isPad: isPad
        )
    }

    private var annotateToggle: some View {
        Button {
            withAnimation(.snappy) { isAnnotating.toggle() }
        } label: {
            Image(systemName: isAnnotating ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle")
                .font(.title3)
                .foregroundStyle(isAnnotating ? DODColor.burntOrange : DODColor.labelSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isAnnotating ? "Done Annotating" : "Annotate Instructions")
        .accessibilityIdentifier("instructions-annotate-toggle")
    }

    @ViewBuilder private var annotationOverlay: some View {
        if showsAnnotateAffordance {
            GeometryReader { geo in
                InstructionsAnnotationCanvas(drawing: $drawing, isActive: isAnnotating)
                    .onAppear { canvasWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, width in canvasWidth = width }
            }
            // Inactive: strokes stay visible but every touch falls through to
            // the recipe (scroll/tap). Active: the canvas takes touches, and
            // `.pencilOnly` still lets a finger scroll the outer ScrollView.
            .allowsHitTesting(isAnnotating)
        }
    }

    private func loadAnnotation() async {
        guard let record = await load() else { return }
        if let restored = try? PKDrawing(data: record.drawingData) {
            drawing = restored
        }
        canvasWidth = CGFloat(record.canvasWidth)
    }

    /// Debounced (~1s) save so a burst of strokes coalesces into one write.
    private func scheduleSave() {
        saveTask?.cancel()
        let record = RecipeAnnotationRecord(
            drawingData: drawing.dataRepresentation(),
            canvasWidth: Double(canvasWidth)
        )
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            await save(record)
        }
    }

    /// Immediate save on annotation-mode exit / view disappear.
    private func saveNow() {
        saveTask?.cancel()
        let record = RecipeAnnotationRecord(
            drawingData: drawing.dataRepresentation(),
            canvasWidth: Double(canvasWidth)
        )
        Task { await save(record) }
    }
    #endif
}
