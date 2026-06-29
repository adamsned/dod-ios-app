import DODDesignSystem
import DODPersistence
import DODSupport
import PhotosUI
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// A single Cooking Journal entry as an editable, personal "page" (CL-273): the
/// cook's photo, the dish + date, and a free-form **reflection** the cook writes
/// about how it went. Pure memory-keeping — `onSave` routes to
/// `RecipeStore.updateCookLog`, which edits an existing entry in place and never
/// logs a new cook, so a reflection or photo can **never** change the cook count
/// and therefore never affects rank. The view sections + logic live in the
/// extension below to keep this struct body under SwiftLint's `type_body_length`.
struct CookJournalEntryView: View {

    let entry: CookLogEntry
    /// Persist the edited entry (note + photo). The journal reloads after this.
    let onSave: (CookLogEntry) async -> Void

    private let photoStore = CookPhotoStore()
    @Environment(\.dismiss) private var dismiss

    @State var note: String
    /// What's shown in the photo slot (existing photo, or a freshly picked one).
    @State var displayImage: Image?
    /// Newly picked/snapped bytes, held until Save so a cancel leaves no orphan.
    @State var pendingImageData: Data?
    /// True once the user removes the existing photo (so Save writes `nil`).
    @State var photoCleared = false
    @State var photoItem: PhotosPickerItem?
    @State var showingPhotosPicker = false
    @State var showingCamera = false
    @State var showingPhotoOptions = false
    @State var isSaving = false
    /// DUT-340: surfaces a photo disk-write failure instead of swallowing it with
    /// `try?` (mirrors the DUT-312 first-cookout path) so the user can retry.
    @State var photoSaveError: String?

    init(entry: CookLogEntry, onSave: @escaping (CookLogEntry) async -> Void) {
        self.entry = entry
        self.onSave = onSave
        _note = State(initialValue: entry.note ?? "")
    }
}

extension CookJournalEntryView {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DODSpacing.lg) {
                photoSection
                headerSection
                reflectionSection
                reassurance
            }
            .padding(DODSpacing.md)
        }
        .background(DODColor.surface)
        .navigationTitle("Journal Entry")
        .dodInlineNavTitle()
        .alert(
            "Couldn't Save Photo",
            isPresented: Binding(
                get: { photoSaveError != nil },
                set: { if !$0 { photoSaveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(photoSaveError ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .tint(DODColor.burntOrange)
                    .disabled(isSaving)
            }
        }
        .task { loadExistingPhoto() }
        .photosPicker(isPresented: $showingPhotosPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in Task { await loadPicked(item) } }
        .confirmationDialog("Photo", isPresented: $showingPhotoOptions, titleVisibility: .hidden) {
            #if canImport(UIKit)
            Button("Take Photo") { showingCamera = true }
            #endif
            Button("Choose Photo") { showingPhotosPicker = true }
            if displayImage != nil {
                Button("Remove Photo", role: .destructive) { clearPhoto() }
            }
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showingCamera) {
            CameraPicker { image in
                showingCamera = false
                guard let image, let data = image.jpegData(compressionQuality: 0.85) else { return }
                pendingImageData = data
                displayImage = Image(uiImage: image)
                photoCleared = false
            }
            .ignoresSafeArea()
        }
        #endif
    }

    // MARK: - Sections

    private var photoSection: some View {
        Button {
            showingPhotoOptions = true
        } label: {
            ZStack {
                if let displayImage {
                    displayImage
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: DODSpacing.md, style: .continuous)
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
            .clipShape(RoundedRectangle(cornerRadius: DODSpacing.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(displayImage == nil ? "Add a photo" : "Change photo")
        .accessibilityIdentifier("journal-entry-photo")
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xxs) {
            Text(entry.recipeTitle)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
            Text(entry.cookedAt.formatted(date: .complete, time: .omitted))
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("Your reflection")
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
            ZStack(alignment: .topLeading) {
                if note.isEmpty {
                    Text("How did this cook go? What would you do differently? Make it yours.")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.labelSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 9)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $note)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 160)
                    .accessibilityIdentifier("journal-entry-note")
            }
            .padding(DODSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                    .fill(DODColor.surfaceElevated)
            )
        }
    }

    private var reassurance: some View {
        HStack(spacing: DODSpacing.xs) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(DODColor.labelSecondary)
            Text("Just for you. Writing here won't change your rank.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Photo + save logic

    private func loadExistingPhoto() {
        guard displayImage == nil, !photoCleared, pendingImageData == nil,
            let id = entry.photoLocalID, let data = photoStore.data(forID: id)
        else { return }
        #if canImport(UIKit)
        if let uiImage = UIImage(data: data) { displayImage = Image(uiImage: uiImage) }
        #endif
    }

    private func loadPicked(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        pendingImageData = data
        photoCleared = false
        #if canImport(UIKit)
        if let uiImage = UIImage(data: data) { displayImage = Image(uiImage: uiImage) }
        #endif
    }

    private func clearPhoto() {
        displayImage = nil
        pendingImageData = nil
        photoItem = nil
        photoCleared = true
    }

    private func save() async {
        isSaving = true
        var photoID = entry.photoLocalID
        if let data = pendingImageData {
            do {
                photoID = try photoStore.save(data)
            } catch {
                // DUT-340: don't swallow the write failure with `try?`. Surface it
                // and bail so the user keeps the photo in the slot and can retry,
                // rather than silently persisting the entry photo-less + dismissing.
                photoSaveError = "We couldn't save your photo. Please try again."
                isSaving = false
                return
            }
        } else if photoCleared {
            photoID = nil
        }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = CookLogEntry(
            id: entry.id,
            recipeID: entry.recipeID,
            recipeTitle: entry.recipeTitle,
            cookedAt: entry.cookedAt,
            note: trimmed.isEmpty ? nil : trimmed,
            personalRating: entry.personalRating,
            photoLocalID: photoID
        )
        await onSave(updated)
        dismiss()
    }
}
