#if canImport(UIKit)
import DODDesignSystem
import SwiftUI
import UIKit

/// Modal sheet that presents the picked photo inside a square crop frame
/// the user can pinch-zoom and pan. The Done toolbar button renders the
/// cropped image at the user's transform and hands it back through the
/// ``onComplete`` callback; Cancel dismisses without committing.
///
/// **Why a custom crop view?** ``PhotosPicker`` does not include a built-in
/// editing or cropping step (its privacy-preserving design intentionally
/// limits the picker to selection). The legacy
/// ``UIImagePickerController(allowsEditing: true)`` does ship a free
/// system square cropper, but requires `NSPhotoLibraryUsageDescription`
/// + triggers the permission alert — worse privacy posture (locked
/// per CL-137 decisions (1)+(2)). Third-party crop libraries (Mantis,
/// BSImagePicker) were considered + rejected per constitution §3 default-
/// no. This view is bounded — `GeometryReader`-sized container + `Image`
/// with `.scaleEffect` + `.offset` + `MagnificationGesture` (1.0..4.0
/// clamp) + `DragGesture` + a dimmed overlay outside the square crop
/// frame — and fits the surface budget.
///
/// **The crop math.** ``cropRect(for:offset:imageSize:cropSize:)`` is a
/// pure helper exposed `static` so the L1 test suite can pin the
/// transform without spinning up a view host. Returns the source-image
/// `CGRect` (in image coordinates) the renderer should sample to produce
/// the cropped output. The output is always square; the crop frame is a
/// fixed 1:1 aspect (locked per CL-137).
///
/// Spec trace: US-44 AC-44.3, AC-44.8; CL-137.
public struct ProfilePhotoCropView: View {

    /// Picked image, presented inside the crop frame.
    public let sourceImage: UIImage

    /// Invoked with the cropped image when the user taps Done. The host
    /// is responsible for handing the image to ``ProfilePhotoStore`` +
    /// dismissing the sheet.
    public let onComplete: (UIImage) -> Void

    /// Invoked when the user taps Cancel. The host dismisses the sheet
    /// without committing.
    public let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var committedScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    public init(
        sourceImage: UIImage,
        onComplete: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.sourceImage = sourceImage
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let cropSize = min(proxy.size.width, proxy.size.height) * 0.85

                ZStack {
                    DODColor.surface.ignoresSafeArea()

                    // The transformable image. `scaledToFit` so the
                    // intrinsic aspect is preserved; the user pans + zooms
                    // via the gestures. The image is bounded by the crop
                    // frame visually — anything outside the square is
                    // dimmed by the overlay.
                    Image(uiImage: sourceImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let next = committedScale * value
                                        scale = Self.clampScale(next)
                                    }
                                    .onEnded { _ in
                                        committedScale = scale
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: committedOffset.width + value.translation.width,
                                            height: committedOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        committedOffset = offset
                                    }
                            )
                        )

                    // Dim everything outside the crop frame so the user
                    // can see exactly what will be kept. `.allowsHitTesting`
                    // false so the overlay doesn't block the gesture
                    // recognisers underneath.
                    cropOverlay(cropSize: cropSize, frameSize: proxy.size)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle("Crop Photo")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbar }
            .accessibilityIdentifier("profile-photo-crop")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { onCancel() }
                .accessibilityIdentifier("profile-photo-crop-cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
                let cropped = renderCroppedImage()
                onComplete(cropped)
            }
            .accessibilityIdentifier("profile-photo-crop-done")
        }
    }

    // MARK: - Overlay

    @ViewBuilder
    private func cropOverlay(cropSize: CGFloat, frameSize: CGSize) -> some View {
        // Dim outside, transparent inside. Drawn as a single rectangle
        // mask via `.mask` so the transparency cuts a clean square
        // — no overdraw on the rest of the canvas.
        Rectangle()
            .fill(Color.black.opacity(0.55))
            .mask(
                Rectangle()
                    .overlay(
                        Rectangle()
                            .frame(width: cropSize, height: cropSize)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
            )
            .overlay(
                // Thin accent stroke on the crop frame so the user can
                // see the exact boundary even in dim light.
                Rectangle()
                    .stroke(DODColor.accent, lineWidth: 1)
                    .frame(width: cropSize, height: cropSize)
            )
            .frame(width: frameSize.width, height: frameSize.height)
    }

    // MARK: - Rendering

    /// Renders the cropped image at the user's transform. Uses
    /// ``cropRect(for:offset:imageSize:cropSize:)`` to compute the
    /// source rect, then draws into a fresh ``UIGraphicsImageRenderer``
    /// at the locked 512×512 output size (the ``ProfilePhotoStore`` will
    /// re-encode to JPEG @ 0.85, so the renderer here just produces the
    /// bitmap).
    private func renderCroppedImage() -> UIImage {
        let imageSize = sourceImage.size
        // Crop frame on screen is the visual `cropSize` but the math
        // operates in source-image coordinates — the helper takes the
        // user's scale + offset and produces a square sub-rect that the
        // renderer will sample to fill the 512×512 output.
        let rect = Self.cropRect(
            for: scale,
            offset: offset,
            imageSize: imageSize,
            cropSize: 1.0  // Normalized — see helper docs.
        )
        let target = CGSize(width: 512, height: 512)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            // Draw the source image into the 512×512 output, sampling
            // the `rect` sub-region. `draw(in:)` scales the rect to fill
            // the target.
            sourceImage.draw(
                in: CGRect(
                    x: -rect.minX * (target.width / rect.width),
                    y: -rect.minY * (target.height / rect.height),
                    width: imageSize.width * (target.width / rect.width),
                    height: imageSize.height * (target.height / rect.height)
                )
            )
        }
    }

    // MARK: - Static helpers (test surface)

    /// Pinch-zoom clamp. Locked 1.0..4.0 per CL-137.
    static let scaleMin: CGFloat = 1.0
    static let scaleMax: CGFloat = 4.0

    /// Clamps a candidate scale into the locked `scaleMin...scaleMax`
    /// range. Pure function so the L1 test suite can pin the clamp
    /// without spinning up a view host.
    public static func clampScale(_ value: CGFloat) -> CGFloat {
        max(scaleMin, min(scaleMax, value))
    }

    /// Computes the source-image rect (in image coordinates) the crop
    /// should sample given the user's current transform. Returns a
    /// square rect centered on the user's pan + zoom after clamping
    /// against the image bounds.
    ///
    /// **Coordinate model.** The pan + zoom values are in the
    /// crop-view's screen coordinate space, but the rect this helper
    /// returns is in the source image's pixel coordinate space — so
    /// the renderer can sample it. The `cropSize` parameter is
    /// normalized (1.0 = "the crop is the full source image side at
    /// scale 1.0"); the helper takes the inverse-scale to find how
    /// much of the source the crop frame visually covers, then walks
    /// the offset by the same factor to translate the rect.
    ///
    /// **Clamping.** If the user pans the image off the screen the
    /// helper clamps the rect to the source-image bounds so the
    /// renderer never samples outside the image (which would produce
    /// the transparent renderer-background bleeding through).
    public static func cropRect(
        for scale: CGFloat,
        offset: CGSize,
        imageSize: CGSize,
        cropSize: CGFloat
    ) -> CGRect {
        // Defensive guards — a zero-side input image shouldn't crash
        // (it would produce a degenerate rect, but it shouldn't trap).
        guard scale > 0, imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: imageSize)
        }
        // The visible source side at scale 1.0 is the shorter dimension
        // of the image — that's the side the crop frame's 1:1 square
        // can fit inside without overshoot. At scale > 1.0 the source
        // side shrinks (more zoom = less source visible).
        let shorterSide = min(imageSize.width, imageSize.height)
        let visibleSide = (shorterSide * cropSize) / scale
        // Centered rect at zero offset.
        let centerX = imageSize.width / 2
        let centerY = imageSize.height / 2
        // The user's offset (in screen pts) maps to source-image pts
        // by dividing by the on-screen scale.
        let translatedX = centerX - (offset.width / scale)
        let translatedY = centerY - (offset.height / scale)
        // Clamp so the visible rect can't slide off the image bounds.
        let halfSide = visibleSide / 2
        let clampedX = max(halfSide, min(imageSize.width - halfSide, translatedX))
        let clampedY = max(halfSide, min(imageSize.height - halfSide, translatedY))
        return CGRect(
            x: clampedX - halfSide,
            y: clampedY - halfSide,
            width: visibleSide,
            height: visibleSide
        )
    }
}

#Preview("ProfilePhotoCropView") {
    if let placeholder = UIImage(systemName: "photo") {
        ProfilePhotoCropView(
            sourceImage: placeholder,
            onComplete: { _ in },
            onCancel: {}
        )
    } else {
        Text("Preview requires UIKit symbols")
    }
}
#endif
