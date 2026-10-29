#if os(iOS) && canImport(PencilKit)
import PencilKit
import SwiftUI

/// A PencilKit drawing surface that overlays the rendered instruction steps so
/// the user can write over them in their own handwriting with an Apple Pencil
/// (iPad-only, v2).
///
/// Key config (see the feature PR for the rationale):
/// - `drawingPolicy = .pencilOnly` — the **Pencil draws**; a **finger passes
///   through** to the recipe's outer `ScrollView` so the page still scrolls
///   normally while annotating.
/// - `isScrollEnabled = false` + `alwaysBounce* = false` — `PKCanvasView`
///   subclasses `UIScrollView`; the OUTER SwiftUI `ScrollView` owns scrolling,
///   so the canvas is a fixed drawing surface sized (by the SwiftUI overlay) to
///   the instructions block. Disabling its own scroll avoids a nested-scroll
///   gesture conflict.
/// - `backgroundColor = .clear` + `isOpaque = false` — the instruction text
///   shows through the canvas.
/// - When inactive, `isUserInteractionEnabled = false` so existing strokes stay
///   VISIBLE but every touch falls through to the recipe; the tool picker hides.
struct InstructionsAnnotationCanvas: UIViewRepresentable {

    /// The drawing, bound in/out. Loaded from persistence, and pushed back out
    /// on every stroke change via ``PKCanvasViewDelegate``.
    @Binding var drawing: PKDrawing

    /// Drives interactivity + the tool-picker palette. `true` in annotation
    /// mode; `false` leaves strokes visible but non-interactive.
    let isActive: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .pencilOnly
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        // The outer SwiftUI ScrollView owns scrolling; this fixed surface must not.
        canvas.isScrollEnabled = false
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        context.coordinator.canvas = canvas
        context.coordinator.apply(isActive: isActive, to: canvas)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        // Adopt an externally-changed drawing (e.g. loaded from disk / cleared)
        // without clobbering in-progress strokes: only reassign on a real diff.
        if canvas.drawing.dataRepresentation() != drawing.dataRepresentation() {
            canvas.drawing = drawing
        }
        context.coordinator.apply(isActive: isActive, to: canvas)
    }

    /// Bridges the UIKit drawing delegate + owns the shared `PKToolPicker`.
    final class Coordinator: NSObject, PKCanvasViewDelegate {

        var parent: InstructionsAnnotationCanvas
        weak var canvas: PKCanvasView?
        private let toolPicker = PKToolPicker()
        /// Guards against re-pushing the drawing we just adopted (avoids a
        /// delegate ↔ binding feedback loop).
        private var isApplyingExternalDrawing = false

        init(_ parent: InstructionsAnnotationCanvas) {
            self.parent = parent
        }

        /// Show/hide the tool picker + first-responder state to match `isActive`.
        func apply(isActive: Bool, to canvas: PKCanvasView) {
            canvas.isUserInteractionEnabled = isActive
            toolPicker.setVisible(isActive, forFirstResponder: canvas)
            if isActive {
                toolPicker.addObserver(canvas)
                canvas.becomeFirstResponder()
            } else {
                toolPicker.removeObserver(canvas)
                canvas.resignFirstResponder()
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingExternalDrawing else { return }
            // Push strokes out so the section view can persist (debounced).
            parent.drawing = canvasView.drawing
        }
    }
}
#endif
