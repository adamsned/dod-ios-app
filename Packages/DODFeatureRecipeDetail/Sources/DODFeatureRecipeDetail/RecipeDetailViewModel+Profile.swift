import DODFeatureProfile
import Foundation

// US-44 / CL-138 / DUT-36 Phase c — profile-gate surface for
// ``RecipeDetailViewModel``. Extracted from `RecipeDetailViewModel.swift`
// so that file stays under the SwiftLint 400-line `file_length` cap
// after the Phase c additions.
//
// Exposes the narrow public seam the view layer needs:
// - ``profileStoreForGate`` / ``profilePhotoStoreForGate`` — handed to
//   ``ProfileEditView`` when the gate CTA presents the modal sheet.
// - ``refreshProfile()`` is declared in the parent file (called from
//   `onAppear` after the initial load); the dependency-bridge
//   accessors here surface the same `dependencies` reference under a
//   public alias so the section view can mount `ProfileEditView`
//   without breaking the module-internal `dependencies` boundary.
//
// Spec trace: US-44 AC-44.10; CL-138; DUT-36 Phase c.

extension RecipeDetailViewModel {

    /// US-44 / CL-138 — expose the profile store reference (when the
    /// composition root wired one) so ``RecipeDetailRatingsSection``
    /// can present ``ProfileEditView`` as a modal sheet over the
    /// recipe from the gate CTA. The `dependencies` property itself
    /// stays module-internal — this is the narrow public seam the
    /// view layer needs and nothing else.
    public var profileStoreForGate: (any ProfileStoring)? {
        dependencies.profileStoreForGate
    }

    #if canImport(UIKit)
    /// US-44 / CL-138 — companion to ``profileStoreForGate`` — UIKit-
    /// gated because ``ProfilePhotoStoring`` returns ``UIImage``.
    public var profilePhotoStoreForGate: (any ProfilePhotoStoring)? {
        dependencies.profilePhotoStoreForGate
    }
    #endif

    /// US-44 / CL-138 / DUT-36 Phase c — re-read the on-device profile
    /// through the dependency seam. Called from ``onAppear()`` for the
    /// initial fetch and from the modal sheet's `.onDisappear` after
    /// the user finishes ``ProfileEditView`` so the Ratings & Reviews
    /// gate flips reactively (the `@Observable` `profile` assignment
    /// triggers SwiftUI re-render which dismisses the gate without any
    /// manual callback wiring).
    ///
    /// **CL-139 / DUT-36 Phase d.** When a profile lands, mirror its
    /// `displayName` + `email` into ``commentAuthorName`` /
    /// ``commentAuthorEmail`` so the comment-submit + rating-submit
    /// paths route the WP REST `author_name` + `author_email` payload
    /// values from the profile. The composer's editable Name / Email
    /// inputs were retired in Phase d — the values are sourced from the
    /// profile, displayed as a static `PostingAsHeader` above the
    /// comment editor, never typed in by the user.
    public func refreshProfile() async {
        profile = await dependencies.loadUserProfile()
        if let profile {
            commentAuthorName = profile.displayName
            commentAuthorEmail = profile.email
        }
    }
}
