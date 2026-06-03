import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 coverage for the T-743 / CL-140 / AC-44.16 dirty-state contract
/// behind ``ProfileEditView``'s back-chevron intercept +
/// `.interactiveDismissDisabled(...)`. Tests the pure static
/// ``ProfileEditView/computeIsDirty(...)`` helper so the truth table
/// is pinned without a view host.
///
/// Truth table:
/// - All three pairs equal → clean (`false`).
/// - Display name differs → dirty (`true`).
/// - Email differs → dirty (`true`).
/// - Photo filename differs → dirty (`true`).
/// - Two or three pairs differ → dirty (`true`).
///
/// Spec trace: US-44 AC-44.16; CL-140.
@Suite("ProfileEditView dirty state (T-743)")
struct ProfileEditViewDirtyStateTests {

    @Test func cleanWhenAllThreePairsMatch() {
        let isDirty = ProfileEditView.computeIsDirty(
            displayName: (current: "Spencer Adams", initial: "Spencer Adams"),
            email: (current: "spencer@example.com", initial: "spencer@example.com"),
            photoFilename: (current: "profile-photo-abc.jpg", initial: "profile-photo-abc.jpg")
        )
        #expect(isDirty == false)
    }

    @Test func cleanWhenAllThreeNilOrEmptyAndMatchInitial() {
        let isDirty = ProfileEditView.computeIsDirty(
            displayName: (current: "", initial: ""),
            email: (current: "", initial: ""),
            photoFilename: (current: nil, initial: nil)
        )
        #expect(isDirty == false)
    }

    @Test func dirtyWhenDisplayNameDiffers() {
        let isDirty = ProfileEditView.computeIsDirty(
            displayName: (current: "Spencer Adams Edited", initial: "Spencer Adams"),
            email: (current: "spencer@example.com", initial: "spencer@example.com"),
            photoFilename: (current: "profile-photo-abc.jpg", initial: "profile-photo-abc.jpg")
        )
        #expect(isDirty)
    }

    @Test func dirtyWhenEmailDiffers() {
        let isDirty = ProfileEditView.computeIsDirty(
            displayName: (current: "Spencer Adams", initial: "Spencer Adams"),
            email: (current: "spencer-new@example.com", initial: "spencer@example.com"),
            photoFilename: (current: "profile-photo-abc.jpg", initial: "profile-photo-abc.jpg")
        )
        #expect(isDirty)
    }

    @Test func dirtyWhenPhotoFilenameDiffers() {
        let isDirty = ProfileEditView.computeIsDirty(
            displayName: (current: "Spencer Adams", initial: "Spencer Adams"),
            email: (current: "spencer@example.com", initial: "spencer@example.com"),
            photoFilename: (current: "profile-photo-NEW.jpg", initial: "profile-photo-abc.jpg")
        )
        #expect(isDirty)
    }

    @Test func dirtyWhenPhotoAddedFromNil() {
        // User uploaded their first photo: initial nil, current
        // populated. Tap-back-now should fire the dialog.
        let isDirty = ProfileEditView.computeIsDirty(
            displayName: (current: "Spencer Adams", initial: "Spencer Adams"),
            email: (current: "spencer@example.com", initial: "spencer@example.com"),
            photoFilename: (current: "profile-photo-fresh.jpg", initial: nil)
        )
        #expect(isDirty)
    }

    @Test func dirtyWhenPhotoRemovedToNil() {
        // User had a photo on appear, then removed it: initial
        // populated, current nil. Tap-back-now should fire the dialog.
        let isDirty = ProfileEditView.computeIsDirty(
            displayName: (current: "Spencer Adams", initial: "Spencer Adams"),
            email: (current: "spencer@example.com", initial: "spencer@example.com"),
            photoFilename: (current: nil, initial: "profile-photo-was-here.jpg")
        )
        #expect(isDirty)
    }

    @Test func dirtyWhenAllThreeDiffer() {
        let isDirty = ProfileEditView.computeIsDirty(
            displayName: (current: "New Name", initial: "Spencer Adams"),
            email: (current: "new@example.com", initial: "spencer@example.com"),
            photoFilename: (current: nil, initial: "profile-photo-abc.jpg")
        )
        #expect(isDirty)
    }
}
