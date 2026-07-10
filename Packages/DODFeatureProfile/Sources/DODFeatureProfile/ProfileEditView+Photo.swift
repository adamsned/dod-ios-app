import DODDesignSystem
import SwiftUI

#if canImport(UIKit)
import PhotosUI
import UIKit
#endif

// US-44 Phase b (T-740) — Photo flow plumbing for `ProfileEditView`.
//
// Extracted from `ProfileEditView.swift` so that file stays under the
// SwiftLint 400-line file_length cap + the 250-line type_body_length
// cap. This file owns the entire picker → crop → save pipeline so the
// host's body stays compact and the per-topic split mirrors the
// `+Voice.swift` + `+CloudSync.swift` pattern in the Feed package.
//
// State assigned here is declared `internal` (no `private`) on the
// host so this cross-file extension can mutate it; SwiftUI's `@State`
// indirection still ensures the assignments drive view updates via the
// parent's runtime state graph.
//
// Spec trace: US-44 AC-44.3, AC-44.8; CL-137.

extension ProfileEditView {

    // MARK: - Photo header

    /// Diameter of the centered profile-photo header avatar. T-754 / CL-151
    /// (DUT-60) settled on 120 (Apple-ID-scale) to fill the top of the form.
    /// Quality-safe: 120pt @3x = 360px, within the 512×512 saved JPG.
    static let headerAvatarDiameter: CGFloat = 120

    /// **T-753 / CL-150 (DUT-59) — centered photo header.** Renders the
    /// profile photo as a large, centered, circular avatar at the TOP of the
    /// form (above the identity fields), floating on the page surface
    /// (`.listRowBackground(.clear)` + hidden separator) like the Contacts /
    /// Apple ID avatar header. The circle is intrinsic to ``ProfilePhotoView``.
    ///
    /// **T-745 / CL-142 / DUT-39 — load-bearing direct-picker gate (preserved).**
    /// In edit mode, tapping the avatar runs ``handleProfilePictureRowTap()``:
    /// no photo → picker; a photo set → the Replace / Edit / Remove action sheet.
    /// The `profile-edit-photo` identifier is preserved on the avatar.
    @ViewBuilder
    var profileEditPhotoSection: some View {
        Section {
            VStack(spacing: DODSpacing.sm) {
                // DUT-416 — the avatar is an interactive picker affordance only
                // in edit mode; view mode shows a plain image + hides the caption.
                if isEditing {
                    Button(action: handleProfilePictureRowTap) { photoHeaderAvatar }
                        .buttonStyle(.plain)
                        .accessibilityHint(photoHeaderCaption)

                    Text(photoHeaderCaption)
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    photoHeaderAvatar
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, DODSpacing.sm)
        }
        // T-753 / CL-150 — float on the page surface (no elevated cell box).
        .listRowBackground(Color.clear)
        #if os(iOS)
        .listRowSeparator(.hidden)
        #endif
    }

    /// The header avatar itself — UIKit passes the photo store so a saved
    /// JPG renders; the macOS slice falls through to the initial-letter
    /// circle. Both clip to `Circle()` inside ``ProfilePhotoView``. Carries the
    /// `profile-edit-photo` identifier + "Profile Picture" label so both the
    /// edit-mode Button and the view-mode plain image expose them (DUT-416).
    @ViewBuilder
    private var photoHeaderAvatar: some View {
        Group {
            #if canImport(UIKit)
            ProfilePhotoView(
                profile: previewProfile,
                diameter: Self.headerAvatarDiameter,
                photoStore: photoStore
            )
            #else
            ProfilePhotoView(
                profile: previewProfile,
                diameter: Self.headerAvatarDiameter
            )
            #endif
        }
        .accessibilityIdentifier("profile-edit-photo")
        .accessibilityLabel("Profile Picture")
    }

    /// State-dependent caption below the header avatar. Mentions Edit
    /// (T-745's Edit Photo action) alongside Replace + Remove when a photo
    /// exists; invites a first upload when none does.
    private var photoHeaderCaption: String {
        #if canImport(UIKit)
        // DUT-416 — Title Case; shown only in edit mode.
        return inFlightPhotoFilename != nil
            ? "Tap the Photo to Replace, Edit, or Remove It."
            : "Tap to Add Profile Picture."
        #else
        return "Photo upload requires UIKit."
        #endif
    }

    /// T-745 / CL-142 / DUT-39 — Profile Picture row tap handler.
    /// Branches based on whether a photo is in-flight: nil → straight
    /// to the picker (no action sheet); populated → surfaces the
    /// confirmation dialog for Replace / Edit / Remove / Cancel. The
    /// conditional gate IS the AC-44.8 entry contract — extracted to
    /// a named function so the call site reads as a single action +
    /// the branch logic stays inspectable from the test harness.
    func handleProfilePictureRowTap() {
        #if canImport(UIKit)
        if inFlightPhotoFilename != nil {
            showPhotoActionDialog = true
        } else {
            isPickerPresented = true
        }
        #endif
    }

    /// A live preview profile used by the photo row's avatar — so the
    /// initial-letter circle updates as the user types their name
    /// before they tap Done, AND the avatar surfaces the in-flight
    /// `photoFilename` so a freshly-cropped photo renders inside the
    /// row immediately rather than waiting for the parent's refresh.
    var previewProfile: UserProfile {
        UserProfile(
            id: existingProfile?.id ?? UUID(),
            displayName: displayName,
            email: email,
            photoFilename: inFlightPhotoFilename
        )
    }
}

// MARK: - Photo-flow modifier chain

extension View {

    /// Wraps the photo flow's modifier chain (`.confirmationDialog`,
    /// `.photosPicker`, `.onChange`, `.sheet`) so the host's body stays
    /// compact. The `#if canImport(UIKit)` branch is fully contained
    /// inside this function body rather than straddling a function
    /// call's `(...)` argument list and `{...}` trailing closure
    /// boundary (which Swift does not allow). On non-UIKit platforms
    /// this is a transparent passthrough.
    @ViewBuilder
    func profileEditPhotoFlow(view: ProfileEditView) -> some View {
        #if canImport(UIKit)
        self
            .confirmationDialog(
                "Profile photo",
                isPresented: view.$showPhotoActionDialog,
                titleVisibility: .hidden
            ) {
                Button("Replace Photo") {
                    view.isPickerPresented = true
                }
                .accessibilityIdentifier("profile-edit-photo-replace")

                Button("Edit Photo") {
                    Task { await view.handleEditPhoto() }
                }
                .accessibilityIdentifier("profile-edit-photo-edit")

                Button("Remove Photo", role: .destructive) {
                    view.handleRemovePhoto()
                }
                .accessibilityIdentifier("profile-edit-photo-remove")

                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(
                isPresented: view.$isPickerPresented,
                selection: view.$pickerSelection,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: view.pickerSelection) { _, newValue in
                guard let newValue else { return }
                Task { await view.loadPickedImage(newValue) }
            }
            .sheet(item: view.$cropCandidate) { candidate in
                ProfilePhotoCropView(
                    sourceImage: candidate.image,
                    onComplete: { cropped in
                        Task { await view.handleCroppedImage(cropped) }
                    },
                    onCancel: {
                        view.cropCandidate = nil
                        view.pickerSelection = nil
                    }
                )
            }
        #else
        self
        #endif
    }
}

// MARK: - Photo handlers

#if canImport(UIKit)
extension ProfileEditView {

    /// Loads the picked image's bytes via `loadTransferable`,
    /// **persists the original** (downscaled to 2048-max per T-745 /
    /// CL-142) so the Edit Photo flow can re-crop without re-picking,
    /// and presents the crop sheet for the user's first Done. Surfaces
    /// a humane prompt in the save-error footer on a load failure
    /// rather than silently dropping the selection.
    @MainActor
    func loadPickedImage(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                saveError = "Couldn't read the selected photo. Try a different one."
                pickerSelection = nil
                return
            }
            // T-745 / CL-142 — persist the picked original before
            // presenting the crop sheet. A photoStore failure here
            // degrades gracefully: the crop sheet still presents
            // (using the in-memory `image`), but `inFlightPhotoOriginalFilename`
            // stays nil so the Edit Photo flow will fall back to
            // re-cropping the cropped derivative for this profile
            // (legacy-fallback path).
            if let photoStore {
                do {
                    let originalFilename = try await photoStore.saveOriginal(image)
                    // Mark the previous original for clean-up if this is
                    // a Replace flow (previous original was non-nil and
                    // different from the just-saved UUID-keyed name).
                    if let previous = inFlightPhotoOriginalFilename, previous != originalFilename {
                        // DUT-353: defer the PERSISTED original to save (so an abandon
                        // keeps it), but delete a this-session superseded original now
                        // — the single-slot marker would otherwise drop it and leak.
                        if previous == existingProfile?.photoOriginalFilename {
                            photoOriginalFilenameToClearOnSave = previous
                        } else {
                            try? await photoStore.clearOriginal(filename: previous)
                        }
                    }
                    inFlightPhotoOriginalFilename = originalFilename
                } catch {
                    // Original-save failure is non-fatal — the crop
                    // pipeline still works and the user can finish the
                    // Replace flow. Edit Photo will fall back to the
                    // cropped derivative on this profile.
                    saveError = "Couldn't save the original photo. Edit Photo may have reduced quality."
                }
            }
            cropCandidate = CropCandidate(image: image)
        } catch {
            saveError = "Couldn't read the selected photo. Try a different one."
            pickerSelection = nil
        }
    }

    /// Persists the cropped image via ``ProfilePhotoStore/save(_:)`` +
    /// updates the in-flight `photoFilename` so the avatar + the next
    /// Done press both surface the new photo. Marks the previous
    /// filename for clean-up on Done so a mid-flow failure leaves the
    /// previous photo intact (write-then-clear-old per CL-137).
    @MainActor
    func handleCroppedImage(_ image: UIImage) async {
        guard let photoStore else {
            // No store wired — graceful no-op. The dialog closes either
            // way; the surface error footer surfaces the diagnostic.
            cropCandidate = nil
            pickerSelection = nil
            return
        }
        do {
            let filename = try await photoStore.save(image)
            // Mark the previous photo for clean-up if this is a Replace
            // flow (the previous filename was non-nil and different).
            if let previous = inFlightPhotoFilename, previous != filename {
                // DUT-353: defer the persisted file to save; delete a this-session
                // superseded file now so the single-slot marker can't leak it.
                if previous == existingProfile?.photoFilename {
                    photoFilenameToClearOnSave = previous
                } else {
                    try? await photoStore.clear(filename: previous)
                }
            }
            inFlightPhotoFilename = filename
            cropCandidate = nil
            pickerSelection = nil
        } catch {
            saveError = "Couldn't save the photo. Try again."
            cropCandidate = nil
            pickerSelection = nil
        }
    }

    /// T-745 / CL-142 — Edit Photo handler. Loads the user's existing
    /// source image (preferring the original via `loadOriginal` when
    /// `photoOriginalFilename` is populated; falling back to the
    /// cropped derivative via `load` for legacy users who only have
    /// the cropped 512×512 on disk) and presents `ProfilePhotoCropView`
    /// for re-crop. On crop Done the existing `handleCroppedImage(_:)`
    /// writes a new UUID-keyed cropped file and the post-save cleanup
    /// deletes the orphan via `photoFilenameToClearOnSave`. The
    /// original stays as-is — only the cropped derivative is
    /// overwritten on Edit.
    @MainActor
    func handleEditPhoto() async {
        guard let photoStore else {
            // No store wired — Edit Photo is meaningless without one;
            // graceful no-op (matches `handleCroppedImage` posture).
            return
        }
        // Prefer the original (T-745 / CL-142) — full-quality source
        // for a meaningful re-crop. Fall back to the cropped derivative
        // for legacy users who have only the 512×512 (documented
        // quality limitation in CL-142 — the re-crop on a 512 source
        // is functional but at reduced effective resolution).
        var loadedImage: UIImage?
        if let originalFilename = inFlightPhotoOriginalFilename {
            loadedImage = await photoStore.loadOriginal(filename: originalFilename)
        }
        if loadedImage == nil, let croppedFilename = inFlightPhotoFilename {
            loadedImage = await photoStore.load(filename: croppedFilename)
        }
        guard let image = loadedImage else {
            // No source on disk to re-crop — surface a humane prompt.
            // This shouldn't happen unless the user wiped Documents
            // via Files.app between picks; the avatar surface already
            // gracefully degrades in that case.
            saveError = "Couldn't load your photo. Try Replace Photo instead."
            return
        }
        // Present the crop sheet via the existing `cropCandidate` +
        // `.sheet(item:)` plumbing — the sheet's onComplete routes to
        // `handleCroppedImage(_:)` which already handles the new-UUID
        // write + orphan-cleanup pattern.
        cropCandidate = CropCandidate(image: image)
    }

    /// Removes the photo: clears the in-flight filename (cropped +
    /// original — T-745 / CL-142), schedules both previous files for
    /// clean-up on Done, falls back to the initial-letter avatar in
    /// the row.
    @MainActor
    func handleRemovePhoto() {
        if let previous = inFlightPhotoFilename {
            photoFilenameToClearOnSave = previous
        }
        inFlightPhotoFilename = nil
        // T-745 / CL-142 — also mark the original for cleanup so
        // Remove leaves the Documents directory in the same clean
        // state as Sign Out + Delete Profile (both files gone).
        if let previousOriginal = inFlightPhotoOriginalFilename {
            photoOriginalFilenameToClearOnSave = previousOriginal
        }
        inFlightPhotoOriginalFilename = nil
    }

    /// T-746 / CL-143 — pure async helper that validates the in-flight
    /// photo filenames against the store's existence checks, nilling
    /// any reference whose file is missing. Extracted so the L1 test
    /// suite can pin the truth table without spinning up the view
    /// host (matches the ``computeIsDirty(...)`` pattern). Inputs:
    /// the current cropped + original filename optionals + the photo
    /// store. Output: a tuple of the same shape with stale references
    /// replaced by `nil`. Self-healing semantics — every consumer of
    /// the filenames (the row-tap conditional, the avatar's
    /// `previewProfile`, the dirty-state check, the Save flow) sees
    /// the corrected state once this helper's output flows back into
    /// the `@State`. Called from the view-mount `.task` modifier in
    /// ``ProfileEditView/body``.
    static func validatePhotoReferences(
        photoFilename: String?,
        photoOriginalFilename: String?,
        photoStore: any ProfilePhotoStoring
    ) async -> (photoFilename: String?, photoOriginalFilename: String?) {
        var validatedCropped = photoFilename
        var validatedOriginal = photoOriginalFilename
        if let filename = photoFilename {
            let exists = await photoStore.exists(filename: filename)
            if !exists { validatedCropped = nil }
        }
        if let filename = photoOriginalFilename {
            let exists = await photoStore.existsOriginal(filename: filename)
            if !exists { validatedOriginal = nil }
        }
        return (validatedCropped, validatedOriginal)
    }
}
#endif
