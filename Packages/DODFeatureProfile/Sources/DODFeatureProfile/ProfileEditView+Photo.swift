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

    // MARK: - Photo section

    /// Phase b — Profile Picture row. Renders an avatar (initial-letter
    /// fallback in Phase a; freshly-cropped photo when one is in-flight)
    /// + a tap target that branches based on whether a photo already
    /// exists: nil → straight to the picker; populated → confirmation
    /// dialog with Replace + Edit + Remove + Cancel (per CL-137 /
    /// AC-44.8 + T-745 / CL-142). The row is rendered as a `Button`
    /// (not a `NavigationLink` — the photo flow is sheet-presented,
    /// not pushed) so the tap region matches the visible row + the
    /// trailing chevron is omitted.
    ///
    /// **T-745 / CL-142 / DUT-39 — load-bearing direct-picker gate.**
    /// The `inFlightPhotoFilename != nil` check below is the
    /// AC-44.8-mandated entry gate: a tap with no photo set goes
    /// straight to the picker (no action sheet); a tap with a photo
    /// set surfaces the action sheet for Replace / Edit / Remove /
    /// Cancel. Pinned as the canonical entry shape — DUT-39 confirmed
    /// the gate already exists in the production code; the spec entry
    /// (CL-142) documents the verification and the intent.
    @ViewBuilder
    var profileEditPhotoSection: some View {
        Section {
            Button(action: handleProfilePictureRowTap) {
                HStack(spacing: DODSpacing.md) {
                    Text("Profile Picture")
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                    Spacer(minLength: 0)
                    #if canImport(UIKit)
                    ProfilePhotoView(
                        profile: previewProfile,
                        diameter: 44,
                        photoStore: photoStore
                    )
                    #else
                    ProfilePhotoView(
                        profile: previewProfile,
                        diameter: 44
                    )
                    #endif
                }
            }
            .accessibilityIdentifier("profile-edit-photo")
        } footer: {
            #if canImport(UIKit)
            if inFlightPhotoFilename != nil {
                Text("Tap the photo to replace or remove it.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            } else {
                Text("Tap to add a profile picture.")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            #else
            Text("Photo upload requires UIKit.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            #endif
        }
        .listRowBackground(DODColor.surfaceElevated)
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

    /// Loads the picked image's bytes via `loadTransferable` and presents
    /// the crop sheet. Surfaces a humane prompt in the save-error footer
    /// on a load failure rather than silently dropping the selection.
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
                photoFilenameToClearOnSave = previous
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

    /// Removes the photo: clears the in-flight filename, schedules the
    /// previous file for clean-up on Done, falls back to the
    /// initial-letter avatar in the row.
    @MainActor
    func handleRemovePhoto() {
        if let previous = inFlightPhotoFilename {
            photoFilenameToClearOnSave = previous
        }
        inFlightPhotoFilename = nil
    }
}
#endif
