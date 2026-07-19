import DODDesignSystem
import DODDomain
import DODPersistence
import DODSupport
import PhotosUI
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// DUT-326 — a self-contained "log this cook" capture sheet for Cook Mode's
/// Done card.
///
/// This is the in-package equivalent of `DODFeatureFeed`'s `CookJournalEntryView`
/// (which Cook Mode cannot import without pulling that whole feature module): a
/// photo slot (PhotosPicker + camera where available) and a free-form caption.
/// On **Save** it persists the photo bytes via ``CookPhotoStore`` and hands the
/// assembled ``CookLogEntry`` to `onSave` — the host (RecipeDetailView) writes
/// it to the journal store. Logging a cook here records a real completed cook
/// and counts toward rank (DUT-326).
///
/// The sections + photo/save logic live in the extension below to keep this
/// struct body under the SwiftLint `type_body_length` cap (mirrors
/// `CookJournalEntryView`).
struct CookModeJournalLogSheet: View {

    let recipe: Recipe
    /// Hand the assembled entry back to the host to persist to the journal.
    let onSave: (CookLogEntry) -> Void

    private let photoStore = CookPhotoStore()
    @Environment(\.dismiss) private var dismiss

    @State var caption: String = ""
    /// What's shown in the photo slot (a freshly picked / snapped image).
    @State var displayImage: Image?
    /// Newly picked/snapped bytes, held until Save so a cancel leaves no orphan.
    @State var pendingImageData: Data?
    @State var photoItem: PhotosPickerItem?
    /// Set when a picked photo can't be materialized (un-downloaded iCloud
    /// asset / transient transfer failure) so the slot can surface a retry cue.
    @State var photoLoadFailed = false
    @State var showingPhotosPicker = false
    @State var showingCamera = false
    @State var showingPhotoOptions = false
    @State var isSaving = false

    init(recipe: Recipe, onSave: @escaping (CookLogEntry) -> Void) {
        self.recipe = recipe
        self.onSave = onSave
    }
}

extension CookModeJournalLogSheet {

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DODSpacing.lg) {
                    photoSection
                    headerSection
                    captionSection
                    reassurance
                }
                .padding(DODSpacing.md)
            }
            .background(DODColor.surface)
            .navigationTitle("Log This Cook")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(DODColor.label)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .tint(DODColor.burntOrange)
                        .disabled(isSaving)
                        .accessibilityIdentifier("cook-mode-journal-save")
                }
            }
            .photosPicker(isPresented: $showingPhotosPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in Task { await loadPicked(item) } }
            .confirmationDialog("Photo", isPresented: $showingPhotoOptions, titleVisibility: .hidden) {
                #if canImport(UIKit)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") { showingCamera = true }
                }
                #endif
                Button("Choose Photo") { showingPhotosPicker = true }
                if displayImage != nil {
                    Button("Remove Photo", role: .destructive) { clearPhoto() }
                }
            }
            #if canImport(UIKit)
            .sheet(isPresented: $showingCamera) {
                CookModeCameraPicker { image in
                    showingCamera = false
                    guard let image, let data = image.jpegData(compressionQuality: 0.85) else { return }
                    pendingImageData = data
                    displayImage = Image(uiImage: image)
                }
                .ignoresSafeArea()
            }
            #endif
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Button {
                showingPhotoOptions = true
            } label: {
                ZStack {
                    if let displayImage {
                        displayImage
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                            .fill(DODColor.burntOrange.opacity(0.1))
                        VStack(spacing: DODSpacing.xs) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(DODColor.burntOrange)
                            Text("Add a photo of your cook")
                                .dodFont(DODType.caption)
                                .foregroundStyle(DODColor.labelSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(displayImage == nil ? "Add a photo" : "Change photo")
            .accessibilityIdentifier("cook-mode-journal-photo")
            if photoLoadFailed {
                Text("Couldn't load that photo. Try again.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.accent)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xxs) {
            Text(recipe.title)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
            Text(Date.now.formatted(date: .complete, time: .omitted))
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("Notes")
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
            ZStack(alignment: .topLeading) {
                if caption.isEmpty {
                    Text("How did it turn out? Anything to remember for next time.")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.labelSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 9)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $caption)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .accessibilityIdentifier("cook-mode-journal-caption")
            }
            .padding(DODSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                    .fill(DODColor.surfaceElevated)
            )
        }
    }

    private var reassurance: some View {
        HStack(spacing: DODSpacing.xs) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(DODColor.labelSecondary)
            Text("Just for you. Saved to your Cooking Journal.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Photo + save logic

    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                photoLoadFailed = false
                pendingImageData = data
                #if canImport(UIKit)
                if let uiImage = UIImage(data: data) { displayImage = Image(uiImage: uiImage) }
                #endif
            } else {
                photoLoadFailed = true
            }
        } catch {
            DODLog.persistence.error("cook journal photo load failed: \(String(describing: error))")
            photoLoadFailed = true
        }
    }

    private func clearPhoto() {
        displayImage = nil
        pendingImageData = nil
        photoItem = nil
    }

    private func save() {
        isSaving = true
        // Persist the photo bytes; the entry keeps only the lightweight id.
        // A disk-write failure must not lose the "I made this" moment — log
        // the cook photo-less rather than blocking Save (mirrors FirstCookoutView).
        var photoID: String?
        if let data = pendingImageData {
            photoID = try? photoStore.save(data)
        }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = CookLogEntry(
            id: UUID(),
            recipeID: recipe.id,
            recipeTitle: recipe.title,
            cookedAt: .now,
            note: trimmed.isEmpty ? nil : trimmed,
            photoLocalID: photoID
        )
        onSave(entry)
        dismiss()
    }
}

#if canImport(UIKit)
/// DUT-326 — minimal camera-capture sheet for the journal-log flow. An
/// in-package twin of `DODFeatureFeed`'s `CameraPicker` (not importable here):
/// wraps `UIImagePickerController` with the `.camera` source. iOS-only, so the
/// whole type is `canImport(UIKit)`-guarded; callers gate the entry point on
/// `UIImagePickerController.isSourceTypeAvailable(.camera)`.
struct CookModeCameraPicker: UIViewControllerRepresentable {

    let onComplete: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onComplete: (UIImage?) -> Void

        init(onComplete: @escaping (UIImage?) -> Void) {
            self.onComplete = onComplete
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onComplete(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onComplete(nil)
        }
    }
}
#endif
