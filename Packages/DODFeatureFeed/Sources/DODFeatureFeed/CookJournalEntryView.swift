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

    /// DUT-611 — longest-edge pixel cap for the entry-detail photo decode. The
    /// slot is at most the screen width wide and 220pt tall (scaled to fill), so
    /// ~1200px stays crisp at 3× Retina while keeping the decoded bitmap a
    /// fraction of a full-res phone photo (~3000–4000px on the long edge).
    private static let detailPhotoMaxPixel = 1200

    let entry: CookLogEntry
    /// Persist the edited entry (note + photo). The journal reloads after this.
    let onSave: (CookLogEntry) async -> Void
    /// DUT-514 — delete this entry (cascades its photo). The journal reloads +
    /// recomputes stats after this. Defaults to a no-op so the Delete affordance
    /// simply doesn't appear for callers (previews/tests) that don't wire it.
    let onDelete: (() async -> Void)?

    private let photoStore = CookPhotoStore()
    /// DUT-611 — decode the existing entry photo OFF the main thread, downsampled,
    /// via the same ``CookThumbnailLoader`` DUT-588 introduced for the journal
    /// list. The detail slot renders larger than a 56pt list thumbnail, so it's
    /// sized to a detail-appropriate longest-edge cap rather than the full native
    /// camera resolution — enough to stay crisp in the 220pt scaled-to-fill slot
    /// while never materializing the full-res bitmap on the main actor.
    @State private var photoLoader = CookThumbnailLoader(maxPixel: CookJournalEntryView.detailPhotoMaxPixel)
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
    /// DUT-514 — drives the delete-confirmation alert.
    @State var showingDeleteConfirm = false

    init(
        entry: CookLogEntry,
        onSave: @escaping (CookLogEntry) async -> Void,
        onDelete: (() async -> Void)? = nil
    ) {
        self.entry = entry
        self.onSave = onSave
        self.onDelete = onDelete
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
                if onDelete != nil { deleteSection }
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
        // DUT-514 — confirm before deleting; a cook counts toward rank.
        .alert("Delete This Cook?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await deleteEntry() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \"\(entry.recipeTitle)\" and its photo from your journal. This can't be undone.")
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .tint(DODColor.burntOrange)
                    .disabled(isSaving)
            }
        }
        .task(id: entry.photoLocalID) { await loadExistingPhoto() }
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
            Text("Your Reflection")
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
            Text("Just for you. Writing here won't change your rank.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// DUT-514 — the destructive Delete affordance inside the entry page. Only
    /// shown when a caller wired `onDelete` (previews/tests that don't stay clean).
    private var deleteSection: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            Label("Delete This Cook", systemImage: "trash")
                .dodFont(DODType.bodyEmphasized)
                .frame(maxWidth: .infinity)
        }
        .disabled(isSaving)
        .accessibilityIdentifier("journal-entry-delete")
    }

    // MARK: - Photo + save logic

    /// DUT-611 — load the existing entry photo OFF the main thread, downsampled,
    /// via ``CookThumbnailLoader`` (the same off-main read + ImageIO downsample
    /// path DUT-588 gave the journal list). The disk read and decode run inside
    /// the loader's detached task; only the final `Image` assignment hops back
    /// here on the MainActor. Preserves the prior guards (skip when a photo is
    /// already shown, was cleared, or a freshly picked one is pending) and the
    /// placeholder fallback for a missing / undecodable file. The enclosing
    /// `.task(id:)` cancels this on disappear.
    private func loadExistingPhoto() async {
        guard displayImage == nil, !photoCleared, pendingImageData == nil else { return }
        guard let id = entry.photoLocalID else { return }
        await photoLoader.loadThumbnail(id: id)
        // A concurrent pick/clear/dismiss may have raced the off-main decode;
        // re-check before adopting the decoded image so we never clobber it.
        guard displayImage == nil, !photoCleared, pendingImageData == nil else { return }
        #if canImport(UIKit)
        if let uiImage = photoLoader.cachedImage(for: id) { displayImage = Image(uiImage: uiImage) }
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

    /// DUT-514 — delete this entry, then pop back to the journal (which reloads +
    /// recomputes its stats in its own `onDelete` handler).
    private func deleteEntry() async {
        guard let onDelete else { return }
        isSaving = true
        await onDelete()
        dismiss()
    }
}
