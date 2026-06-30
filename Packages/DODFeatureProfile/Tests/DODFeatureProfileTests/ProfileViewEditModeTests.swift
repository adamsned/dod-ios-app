import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 coverage for the DUT-416 / CL-291 view-vs-edit mode navigation-title
/// contract behind ``ProfileEditView``. Opening an existing profile from
/// Settings lands in read-only **view mode** ("Profile" + an "Edit Profile"
/// toolbar button); tapping Edit enters edit mode ("Edit Profile"); the
/// "New Profile" setup flow (`existingProfile == nil`) is always editing.
/// Tests the pure static ``ProfileEditView/navigationTitle(hasExistingProfile:isEditing:)``
/// helper so the three states are pinned without a view host.
///
/// Spec trace: US-44; CL-291.
@Suite("ProfileEditView view/edit mode (DUT-416)")
struct ProfileViewEditModeTests {

    @Test func existingProfileViewModeReadsProfile() {
        let title = ProfileEditView.navigationTitle(hasExistingProfile: true, isEditing: false)
        #expect(title == "Profile")
    }

    @Test func existingProfileEditModeReadsEditProfile() {
        let title = ProfileEditView.navigationTitle(hasExistingProfile: true, isEditing: true)
        #expect(title == "Edit Profile")
    }

    @Test func newProfileAlwaysReadsNewProfile() {
        // The setup flow is always editing — both branches resolve to the
        // same title so a stray `isEditing` flip can never mislabel it.
        #expect(ProfileEditView.navigationTitle(hasExistingProfile: false, isEditing: true) == "New Profile")
        #expect(ProfileEditView.navigationTitle(hasExistingProfile: false, isEditing: false) == "New Profile")
    }
}
