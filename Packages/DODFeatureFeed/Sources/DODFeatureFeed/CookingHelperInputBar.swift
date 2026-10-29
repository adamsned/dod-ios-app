import DODDesignSystem
import SwiftUI

#if canImport(UIKit)
import PhotosUI
import UIKit
#endif

/// The ChatGPT-style input bar for "Ask Dutch Oven Daddy": a rounded field that
/// grows with the text, the send button inside it on the right, and (where the
/// model supports vision) a photo button that lets the cook attach a picture
/// from the camera or library. Pinned above the keyboard by the sheet via
/// `safeAreaInset`. Split out of `CookingHelperSheet.swift` for the length cap.
///
/// The photo machinery is `canImport(UIKit)`-gated so the macOS test slice still
/// builds; on macOS the bar is just the text field + send button.
struct CookingHelperInputBar: View {

    @Bindable var viewModel: CookingHelperViewModel
    /// The field's placeholder (general helper vs Cook Mode's recipe chat).
    var placeholder = "Ask about cooking or cast iron"
    /// Fired on send with the attached photo's JPEG bytes, or `nil` for a
    /// text-only ask. The sheet calls `viewModel.ask(imageData:)` with it.
    let onSend: (Data?) -> Void

    #if canImport(UIKit)
    @State private var pendingImageData: Data?
    @State private var pendingPreview: Image?
    @State private var photosItem: PhotosPickerItem?
    @State private var showSourceDialog = false
    @State private var showLibrary = false
    @State private var showCamera = false
    #endif

    var body: some View {
        bar
            #if canImport(UIKit)
        .confirmationDialog("Add a Photo", isPresented: $showSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showLibrary, selection: $photosItem, matching: .images)
        .onChange(of: photosItem) { _, item in
            Task { await loadPickedImage(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { handleCameraImage($0) }
            .ignoresSafeArea()
        }
            #endif
    }

    private var bar: some View {
        VStack(spacing: DODSpacing.xs) {
            #if canImport(UIKit)
            if let pendingPreview {
                attachedImageRow(pendingPreview)
            }
            #endif

            HStack(alignment: .bottom, spacing: DODSpacing.xs) {
                #if canImport(UIKit)
                if viewModel.supportsImageInput {
                    photoButton
                }
                #endif
                inputField
            }
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.xs)
        .background(DODColor.surface)
    }

    // MARK: - Field + send

    private var inputField: some View {
        HStack(alignment: .bottom, spacing: DODSpacing.xxs) {
            TextField(placeholder, text: $viewModel.question, axis: .vertical)
                .lineLimit(1...5)
                .dodFont(DODType.body)
                .textFieldStyle(.plain)
                .padding(.leading, DODSpacing.md)
                .padding(.vertical, DODSpacing.sm)
                .accessibilityIdentifier("dod.cookingTools.helper.questionField")

            sendButton
        }
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
    }

    private var sendButton: some View {
        Button {
            send()
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(canSend ? DODColor.accent : DODColor.labelSecondary.opacity(0.4))
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .padding(.trailing, DODSpacing.xxs)
        .padding(.bottom, DODSpacing.xxs)
        .accessibilityIdentifier("dod.cookingTools.helper.send")
        .accessibilityLabel("Send")
    }

    private var canSend: Bool {
        let hasText = !viewModel.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || hasPendingImage) && !viewModel.isResponding
    }

    private var hasPendingImage: Bool {
        #if canImport(UIKit)
        return pendingImageData != nil
        #else
        return false
        #endif
    }

    private func send() {
        guard canSend else { return }
        #if canImport(UIKit)
        let data = pendingImageData
        clearImage()
        onSend(data)
        #else
        onSend(nil)
        #endif
    }

    // MARK: - Photo (iOS)

    #if canImport(UIKit)
    private var photoButton: some View {
        Button {
            showSourceDialog = true
        } label: {
            Image(systemName: "photo")
                .font(.system(size: 24))
                .foregroundStyle(DODColor.accent)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isResponding)
        .accessibilityIdentifier("dod.cookingTools.helper.photo")
        .accessibilityLabel("Add a photo")
    }

    private func attachedImageRow(_ preview: Image) -> some View {
        HStack(spacing: DODSpacing.sm) {
            preview
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: DODRadius.widgetThumbnail, style: .continuous))
            Text("Photo attached")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            Spacer(minLength: 0)
            Button {
                clearImage()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(DODColor.labelSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove photo")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func clearImage() {
        pendingImageData = nil
        pendingPreview = nil
        photosItem = nil
    }

    private func loadPickedImage(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        setImage(data)
    }

    private func handleCameraImage(_ image: UIImage?) {
        showCamera = false
        guard let image, let data = image.jpegData(compressionQuality: 0.8) else { return }
        setImage(data)
    }

    private func setImage(_ data: Data) {
        guard let uiImage = UIImage(data: data) else { return }
        pendingImageData = data
        pendingPreview = Image(uiImage: uiImage)
    }
    #endif
}
