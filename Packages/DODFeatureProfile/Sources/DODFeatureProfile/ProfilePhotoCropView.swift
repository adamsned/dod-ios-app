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
/// **The crop math.** ``cropRect(for:offset:imageSize:cropDiameterInScreenPoints:displayedImageScaleFactor:)``
/// is a pure helper exposed `static` so the L1 test suite can pin the
/// transform without spinning up a view host. Returns the source-image
/// `CGRect` (in image pixels) the renderer should sample. T-748 / CL-145
/// (DUT-54) amended the signature to take screen-pt diameter + the
/// scaledToFit ratio so offset (also screen-pts) and diameter convert
/// to source pixels correctly. See CL-145 for the pre-T-748 units bug.
///
/// Spec trace: US-44 AC-44.3, AC-44.8; CL-137; CL-145.
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

    /// T-748 / CL-145 — captured `GeometryReader` proxy size so the
    /// toolbar Done button (outside the GeometryReader closure) can read
    /// it at crop time. Drives the `cropDiameterInScreenPoints` +
    /// `displayedImageScaleFactor` computations in ``renderCroppedImage()``.
    /// `.zero` until the first layout pass resolves the proxy.
    @State private var capturedProxySize: CGSize = .zero

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
                // T-748 / CL-145 — capture the proxy size into @State so
                // `renderCroppedImage()` (called from the toolbar Done
                // button, which lives outside this `GeometryReader`
                // closure) can read it to compute the displayed-image
                // scale factor + the crop circle's screen-pt diameter
                // and convert offset + diameter to source pixels.
                .onAppear { capturedProxySize = proxy.size }
                .onChange(of: proxy.size) { _, newValue in
                    capturedProxySize = newValue
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
        // Dim outside, transparent inside. Drawn as a full-frame
        // rectangle mask with a Circle "hole" punched out via
        // `.destinationOut` so the transparency cuts a clean circle.
        // The visible crop window IS a circle so the user sees how
        // the avatar will actually look post-save (every avatar
        // render site in the app clips to `Circle()` per AC-44.15).
        //
        // **Math UNCHANGED.** `cropRect(for:offset:imageSize:cropSize:)`
        // still produces a square rect that the renderer samples into
        // a 512×512 square output bitmap, which `ProfilePhotoStore`
        // re-encodes to JPG at 0.85 quality (locked per CL-137). Only
        // the visual overlay shape changes; the saved file stays
        // square JPG. Render-side `.clipShape(Circle())` is what makes
        // the user's eye see a circle in the final UI. Rationale for
        // not switching the on-disk format to PNG-with-alpha: file size
        // (5-10× larger), couples storage format to presentation shape,
        // and the user can always re-clip a square source at render
        // time but cannot recover destroyed corners (CL-140 (2)).
        Rectangle()
            .fill(Color.black.opacity(0.55))
            .mask(
                Rectangle()
                    .overlay(
                        Circle()
                            .frame(width: cropSize, height: cropSize)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
            )
            .overlay(
                // Thin accent stroke on the crop frame so the user can
                // see the exact boundary even in dim light.
                Circle()
                    .stroke(DODColor.accent, lineWidth: 1)
                    .frame(width: cropSize, height: cropSize)
            )
            .frame(width: frameSize.width, height: frameSize.height)
    }

    // MARK: - Rendering

    /// Renders the cropped image at the user's transform into a
    /// 512×512 bitmap (the ``ProfilePhotoStore`` re-encodes to JPEG @
    /// 0.85). Reads `capturedProxySize` (set by the GeometryReader's
    /// `.onAppear` / `.onChange`) to compute the on-screen crop circle
    /// diameter + the scaledToFit factor, which the cropRect helper
    /// needs to convert offset + diameter to source pixels per
    /// T-748 / CL-145.
    private func renderCroppedImage() -> UIImage {
        let imageSize = sourceImage.size
        // Compute the visible crop circle diameter in screen pts — same
        // formula as the GeometryReader closure's `cropSize` constant
        // (locked per CL-137: 0.85 of the proxy's shorter side).
        let cropDiameterInScreenPoints = min(
            capturedProxySize.width,
            capturedProxySize.height
        ) * 0.85
        // Compute the scaledToFit ratio: source-px → screen-pt.
        // SwiftUI's `.scaledToFit()` fits the image entirely within the
        // proxy preserving aspect; the limiting factor is the smaller
        // of the two per-axis ratios.
        let displayedImageScaleFactor = Self.displayedImageScaleFactor(
            imageSize: imageSize,
            proxySize: capturedProxySize
        )
        let rect = Self.cropRect(
            for: scale,
            offset: offset,
            imageSize: imageSize,
            cropDiameterInScreenPoints: cropDiameterInScreenPoints,
            displayedImageScaleFactor: displayedImageScaleFactor
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

    /// Computes the source-image rect (in image pixel coordinates) the
    /// crop should sample given the user's current transform. Returns a
    /// square rect centered on the user's pan + zoom after clamping
    /// against the image bounds + the source's shorter side.
    ///
    /// **Coordinate model (T-748 / CL-145).** `offset` arrives in screen
    /// points (`DragGesture.translation`); `cropDiameterInScreenPoints`
    /// is the visible circle's screen-pt diameter; both convert to
    /// source pixels via `displayedImageScaleFactor * scale`. The
    /// `displayedImageScaleFactor` is SwiftUI's `.scaledToFit()` ratio
    /// (source-px → screen-pt) — see
    /// ``displayedImageScaleFactor(imageSize:proxySize:)``.
    public static func cropRect(
        for scale: CGFloat,
        offset: CGSize,
        imageSize: CGSize,
        cropDiameterInScreenPoints: CGFloat,
        displayedImageScaleFactor: CGFloat
    ) -> CGRect {
        // Defensive guards — a zero-side input image, zero scale, or
        // zero scale factor shouldn't crash (each would otherwise produce
        // a divide-by-zero or a degenerate rect). Return the source
        // bounds so the renderer noops gracefully.
        guard scale > 0,
              imageSize.width > 0,
              imageSize.height > 0,
              displayedImageScaleFactor > 0
        else {
            return CGRect(origin: .zero, size: imageSize)
        }
        // Convert the crop circle's screen diameter to source pixels:
        // 1 source pixel = `displayedImageScaleFactor` screen pts at
        // user scale 1.0; at user scale K the image is rendered K× larger
        // on screen so each source pixel covers K× more screen pts. So
        // 1 screen pt = `1 / (displayedImageScaleFactor * scale)` source pixels.
        let cropInSourcePixels = cropDiameterInScreenPoints /
            (displayedImageScaleFactor * scale)
        // Clamp the crop side to the shorter source dimension — a circle
        // wider than the source can't honestly sample more than the
        // source's bounds (the renderer would otherwise stamp the source's
        // edges with the renderer-clear background).
        let shorterSide = min(imageSize.width, imageSize.height)
        let visibleSide = min(cropInSourcePixels, shorterSide)
        // Convert the user's drag offset from screen pts to source pixels
        // via the same `displayedImageScaleFactor * scale` factor.
        let offsetInSourcePixels = CGSize(
            width: offset.width / (displayedImageScaleFactor * scale),
            height: offset.height / (displayedImageScaleFactor * scale)
        )
        // Centered rect at zero offset; positive drag right = crop walks
        // left in source coords (the image moved right under the fixed
        // crop window).
        let centerX = imageSize.width / 2
        let centerY = imageSize.height / 2
        let translatedX = centerX - offsetInSourcePixels.width
        let translatedY = centerY - offsetInSourcePixels.height
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

    /// T-748 / CL-145 — computes the SwiftUI `.scaledToFit()` ratio of
    /// source pixels to screen points for an image of `imageSize`
    /// rendered inside a frame of `proxySize`. The fit-to-frame ratio
    /// is the **smaller** of the two per-axis ratios (so the image
    /// fits entirely within the proxy on its limiting dimension).
    /// Returns 0 if either input is degenerate so call sites can
    /// guard before dividing.
    ///
    /// Exposed `static` so the L1 test suite can pin the conversion
    /// without spinning up a view host.
    public static func displayedImageScaleFactor(
        imageSize: CGSize,
        proxySize: CGSize
    ) -> CGFloat {
        guard imageSize.width > 0,
              imageSize.height > 0,
              proxySize.width > 0,
              proxySize.height > 0
        else {
            return 0
        }
        return min(
            proxySize.width / imageSize.width,
            proxySize.height / imageSize.height
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
