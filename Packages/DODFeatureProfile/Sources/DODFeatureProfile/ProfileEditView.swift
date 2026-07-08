import DODDesignSystem
import DODSupport
import SwiftUI

#if canImport(UIKit)
import PhotosUI
import UIKit
#endif

/// Push destination for editing (or creating) the on-device user
/// profile. Reached from ``ProfileSection``; back-stack-pushes from
/// `SettingsView`. Also presented as a modal sheet from the recipe-
/// detail Ratings gate CTA (Phase c).
///
/// Three top-level surfaces: **Identity fields** (Display Name + Email
/// TextFields, both required, basic regex validation per
/// ``UserProfile/validateEmail(_:)``); **Profile Picture row** (Phase
/// b `PhotosPicker` + crop + Documents-directory JPG; Replace / Remove
/// confirmation when one exists); **Sign Out + Delete Profile**
/// buttons (both clear Keychain + photo file for local-only v1; Delete
/// fronts a destructive confirmation alert per App Store 5.1.1(v),
/// Sign Out is friendlier everyday wording).
///
/// **Toolbar (T-743 / CL-140 / AC-44.16).** Back chevron (top-left)
/// intercepts dismissal when `isDirty` to front the unsaved-changes
/// `.confirmationDialog`; system back is suppressed via
/// `.navigationBarBackButtonHidden(true)`. Save button (top-right;
/// renamed from "Done") persists + dismisses; disabled until form
/// validates. The toolbar content + dirty-state machinery live in
/// `ProfileEditView+DirtyState.swift`.
///
/// **Modal-sheet drag-down guard.** `.interactiveDismissDisabled(isDirty)`
/// blocks the swipe-to-dismiss gesture in the Phase c gate-CTA modal-
/// sheet context when the form is dirty; user routes through the back
/// chevron (and the dialog). No-op on push.
///
/// **Sign Out + Delete Profile bypass the unsaved-changes dialog by
/// construction** — both call `handleClear()` (clear + dismiss)
/// without consulting `isDirty`. Delete Profile's existing destructive
/// alert "Delete your profile?" is preserved and distinct.
///
/// Spec trace: US-44 AC-44.2..AC-44.4, AC-44.8, AC-44.9, AC-44.16;
/// CL-136, CL-137, CL-140.
public struct ProfileEditView: View {

    let store: any ProfileStoring
    let existingProfile: UserProfile?
    /// Closure invoked after a successful save / sign-out / delete so
    /// the parent (`SettingsViewModel`) can refresh its cached
    /// `profile` property. Matches the cache-clear feedback callback
    /// pattern the rest of `SettingsView` uses.
    let onProfileChanged: @MainActor () async -> Void
    #if canImport(UIKit)
    /// Phase b — Photo store collaborator used by the Profile Picture
    /// row to persist + clear the on-disk JPG. `nil` for previews and
    /// test hosts that don't wire one — the row falls back to the
    /// Phase a stub behavior in that case (the picker still wires up
    /// but the save step gracefully no-ops). UIKit-gated because the
    /// store returns ``UIImage``.
    let photoStore: (any ProfilePhotoStoring)?
    #endif

    /// DUT-217: the AppleAuthSession (session + Apple refresh token) written at
    /// sign-in via ``AppleProfileSignIn``. "Sign Out" / "Delete Profile" must
    /// clear this too — and **Delete must revoke** the token (App Store
    /// 5.1.1(v)) — or the editor's teardown leaves a live, un-revoked token.
    let sessionStore: any AppleAuthSessionStoring
    let revoker: (any SiwaRevoking)?
    /// DUT-417 — composition-root hooks for the view-mode stats section (Cook
    /// Rank + counts + journal link). Nil for previews / snapshots / the
    /// new-profile setup flow → the section is hidden.
    let statsHooks: ProfileStatsHooks?
    /// DUT-565 — composition-root seam for extra local-state clears that live in
    /// sibling feature packages (recent searches in DODFeatureSearch, comment
    /// moderation in DODFeatureRecipeDetail). Run as part of `teardown` on BOTH
    /// Sign Out and Delete (the `Bool` is `revoke`). Nil off the teardown path —
    /// keeps DODFeatureProfile free of a dependency edge onto those packages.
    let extraTeardown: (@MainActor (Bool) async -> Void)?

    @State var displayName: String = ""
    @State var email: String = ""
    /// Non-private so `ProfileEditView+Save.swift` can write to it
    /// when the email validation fails (T-745 / CL-142 file_length
    /// split).
    @State var emailValidationError: String?
    @State var saveError: String?
    @State var saveSuccessTick = 0  // DUT-693 PR4 — save-success signal: .success haptic + snackbar token
    @State var savedConfirmationMessage: String?  // DUT-693 PR4 — in-place "Profile saved." snackbar; nil hides
    /// DUT — auth-success haptic signal, bumped by the `+AppleSignIn` / `+Teardown`
    /// handlers (non-private for that); drives the body's `.sensoryFeedback`.
    @State var authSuccessTick = 0
    /// Non-private so `ProfileEditView+SignOut.swift`'s Delete button can set it.
    @State var showDeleteConfirmation = false
    /// DUT-429 — gates Sign Out behind a confirmation, mirroring Delete (the
    /// alert lives on the Sign Out section in `ProfileEditView+SignOut`).
    @State var showSignOutConfirmation = false
    /// DUT-281 — true when a session exists (seeded from `sessionStore` on appear;
    /// set by a successful Apple/Google sign-in). Gates `signOutSection` so Sign
    /// Out / Delete stays reachable even when no `UserProfile` was written (Apple
    /// withholds name/email on re-auth) — otherwise a live session + token could
    /// never be revoked through the UI. Non-private so the sign-in handlers in
    /// `+AppleSignIn.swift` can set it.
    @State var hasSession = false
    /// Non-private so `ProfileEditView+DirtyState.swift` can read it
    /// from the Save button's `.disabled(...)` modifier (T-743).
    @State var isSubmitting = false
    /// DUT-416 / CL-291 — view-vs-edit mode. An existing profile opens in
    /// read-only view mode (static rows, photo not tappable, captions hidden,
    /// "Edit Profile" toolbar); the new-profile setup flow starts editing.
    /// Seeded in `init` so there's no first-render flash. Non-private so the
    /// toolbar + section builders in the satellite files can read/set it.
    @State var isEditing: Bool
    /// DUT-417 — the loaded view-mode stats; nil until `statsHooks.load()`
    /// resolves on appear, or when no provider is wired (section stays hidden).
    /// Non-private so the `+Stats` section builder reads it.
    @State var loadedStats: ProfileStats?
    /// T-743 / CL-140 / AC-44.16 — initial-value snapshots captured on
    /// `.onAppear` for the dirty-state comparison. Non-private so
    /// `ProfileEditView+DirtyState.swift`'s `isDirty` can read them.
    @State var initialDisplayName: String = ""
    @State var initialEmail: String = ""
    @State var initialPhotoFilename: String?
    /// T-743 / CL-140 — `true` while the unsaved-changes
    /// `confirmationDialog` is presented. Non-private so
    /// `ProfileEditView+DirtyState.swift` can set it from the
    /// back-chevron tap closure.
    @State var showLeaveConfirmation = false
    /// T-743 / CL-140 — guards the initial-value snapshot seeding so a
    /// re-mount doesn't re-seed from already-edited values.
    @State private var didCaptureInitialValues = false
    /// Phase b — the in-flight `photoFilename`. Seeded from
    /// `existingProfile?.photoFilename` on first appear; updated when
    /// the user crops a new photo (Replace / first upload) or removes
    /// the existing one. Distinct from `existingProfile?.photoFilename`
    /// so we can compute the "did this filename change" diff in
    /// ``handleSave()`` + ``clearPreviousPhotoIfReplaced(...)``.
    @State var inFlightPhotoFilename: String?
    /// Set to the filename of the previously-saved photo when the user
    /// replaces it — cleared post-save so a mid-flow failure leaves
    /// the previous file intact (write-then-clear-old per CL-137).
    @State var photoFilenameToClearOnSave: String?
    /// T-745 / CL-142 — the in-flight `photoOriginalFilename`. Parallel
    /// to `inFlightPhotoFilename`; nil for legacy users with only the
    /// cropped derivative (Edit Photo falls back to re-cropping that).
    @State var inFlightPhotoOriginalFilename: String?
    /// T-745 / CL-142 — write-then-clear-old mirror of
    /// `photoFilenameToClearOnSave` for the original picked image.
    @State var photoOriginalFilenameToClearOnSave: String?
    #if canImport(UIKit)
    /// Phase b — `PhotosPicker` selection binding. Becomes non-nil
    /// when the user picks an image; `.onChange` then loads its bytes
    /// and presents the crop sheet.
    @State var pickerSelection: PhotosPickerItem?
    /// Phase b — Image handed to ``ProfilePhotoCropView``. Becomes
    /// non-nil when the picker selection's `loadTransferable` resolves,
    /// driving the crop sheet's identifiable-item presentation.
    @State var cropCandidate: CropCandidate?
    /// Phase b — Whether the Replace / Remove / Cancel confirmation
    /// dialog is showing (true when the user taps the row + a photo
    /// already exists).
    @State var showPhotoActionDialog = false
    /// Whether the `PhotosPicker` is showing (driven by the row tap
    /// when no photo exists OR by the Replace branch of the action
    /// dialog).
    @State var isPickerPresented = false
    #endif

    /// Non-private so `ProfileEditView+DirtyState.swift` can call it
    /// from the back-chevron tap closure (T-743 / CL-140 / AC-44.16).
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion  // DUT — gates the edit-mode cross-fade

    #if canImport(UIKit)
    public init(
        store: any ProfileStoring,
        existingProfile: UserProfile?,
        onProfileChanged: @MainActor @escaping () async -> Void,
        photoStore: (any ProfilePhotoStoring)? = nil,
        sessionStore: any AppleAuthSessionStoring = KeychainAppleAuthSessionStore(),
        revoker: (any SiwaRevoking)? = SiwaRevokeConfig.production.isConfigured
            ? SiwaRevokeClient(config: SiwaRevokeConfig.production) : nil,
        statsHooks: ProfileStatsHooks? = nil,
        extraTeardown: (@MainActor (Bool) async -> Void)? = nil
    ) {
        self.store = store
        self.existingProfile = existingProfile
        self.onProfileChanged = onProfileChanged
        self.photoStore = photoStore
        self.sessionStore = sessionStore
        self.revoker = revoker
        self.statsHooks = statsHooks
        self.extraTeardown = extraTeardown
        // DUT-416 — existing profile opens in view mode; new-profile setup edits.
        _isEditing = State(initialValue: existingProfile == nil)
    }
    #else
    public init(
        store: any ProfileStoring,
        existingProfile: UserProfile?,
        onProfileChanged: @MainActor @escaping () async -> Void,
        sessionStore: any AppleAuthSessionStoring = KeychainAppleAuthSessionStore(),
        revoker: (any SiwaRevoking)? = SiwaRevokeConfig.production.isConfigured
            ? SiwaRevokeClient(config: SiwaRevokeConfig.production) : nil,
        statsHooks: ProfileStatsHooks? = nil,
        extraTeardown: (@MainActor (Bool) async -> Void)? = nil
    ) {
        self.store = store
        self.existingProfile = existingProfile
        self.onProfileChanged = onProfileChanged
        self.sessionStore = sessionStore
        self.revoker = revoker
        self.statsHooks = statsHooks
        self.extraTeardown = extraTeardown
        // DUT-416 — existing profile opens in view mode; new-profile setup edits.
        _isEditing = State(initialValue: existingProfile == nil)
    }
    #endif

    public var body: some View {
        Form {
            // T-753 / CL-150 (DUT-59) — the photo header is the FIRST
            // section now: a large, centered, circular avatar + caption
            // above the display-name + email fields (was a 44pt trailing
            // avatar in a labeled row below the identity fields).
            profileEditPhotoSection
            // DUT-238 — providers (Apple / Google) + email fields in one menu.
            signInSection
            // DUT-417 — Cook Rank + counts + journal link, view mode only.
            if !isEditing {
                profileStatsSection
            }
            signOutSection
            if let saveError {
                Section {
                    Text(saveError)
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                }
                .listRowBackground(DODColor.surfaceElevated)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DODColor.surface)
        .navigationTitle(navigationTitleText)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        #endif
        .toolbar { toolbarContent }
        // T-743 / CL-140 / AC-44.16 — prevent drag-to-dismiss past
        // unsaved changes when presented as a modal sheet (Phase c
        // gate-CTA path). No-op on push (push has no swipe-down
        // gesture); safe to apply unconditionally.
        .interactiveDismissDisabled(isDirty)
        .profileSavedConfirmation(message: $savedConfirmationMessage, token: saveSuccessTick)
        // DUT — cross-fade the view/edit swap (stats section pops in/out on `isEditing`),
        // value-scoped so only `isEditing` animates; auth-event success tap (sign-in/out/delete).
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isEditing)
        .sensoryFeedback(.success, trigger: authSuccessTick)
        .alert("Delete your profile?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await handleDelete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove your display name, email, and any future comments will be attributed to a guest.")
        }
        // T-743 / CL-140 / AC-44.16 — the custom back chevron taps into
        // this dialog when the form is dirty. Sign Out + Delete Profile
        // bypass by construction (their button closures call
        // `handleClear()` + `dismiss()` directly without consulting
        // `isDirty` or setting `showLeaveConfirmation`).
        .confirmationDialog(
            "You Have Unsaved Changes",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Continue Editing") {
                showLeaveConfirmation = false
            }
            Button("Leave Without Saving", role: .destructive) {
                showLeaveConfirmation = false
                #if canImport(UIKit)
                discardUnsavedPhotoFiles()  // DUT-353
                #endif
                // DUT-416 — for an existing profile this is the "Cancel edit"
                // path: revert + drop to view mode. New-profile setup dismisses.
                if existingProfile != nil {
                    exitEditMode()
                } else {
                    dismiss()
                }
            }
        }
        .profileEditPhotoFlow(view: self)
        // DUT-424: reload on every appear so the Cook Rank + counts aren't stale
        // after cooking (or editing a journal rating) and returning to this
        // still-mounted screen. This is the sole stats loader — it also covers
        // the first appear (DUT-417's "load once when a provider is wired"), so
        // a separate `.task` first-load is intentionally omitted to avoid a
        // double load on the first appear (DUT-725).
        .onAppear {
            if let statsHooks { Task { loadedStats = await statsHooks.load() } }
        }
        .onAppear {
            // Seed the fields from the existing profile (if any) only
            // once — re-applying on every body recompute would clobber
            // the user's in-flight edits.
            if let existingProfile, displayName.isEmpty, email.isEmpty {
                displayName = existingProfile.displayName
                email = existingProfile.email
            }
            if inFlightPhotoFilename == nil {
                inFlightPhotoFilename = existingProfile?.photoFilename
            }
            #if canImport(UIKit)
            // T-745 / CL-142 — seed the original-filename alongside the
            // cropped derivative. Guarded by the same first-appear
            // pattern so a re-mount doesn't clobber the user's in-flight
            // Edit / Replace edits.
            if inFlightPhotoOriginalFilename == nil {
                inFlightPhotoOriginalFilename = existingProfile?.photoOriginalFilename
            }
            #endif
            // T-743 / CL-140 — capture the initial-value snapshots for
            // dirty-state tracking. Guarded by `didCaptureInitialValues`
            // so a second `.onAppear` (from a re-mount) doesn't re-seed
            // the snapshots from already-edited values.
            if !didCaptureInitialValues {
                initialDisplayName = existingProfile?.displayName ?? ""
                initialEmail = existingProfile?.email ?? ""
                initialPhotoFilename = existingProfile?.photoFilename
                hasSession = (try? sessionStore.load()) != nil  // DUT-281
                didCaptureInitialValues = true
            }
        }
        #if canImport(UIKit)
        // T-746 / CL-143 — stale-`photoFilename` self-heal at view
        // mount. The `.onAppear` above seeded the in-flight filenames
        // from `existingProfile`, but those can be STALE references
        // to deleted files (simulator Keychain persists across
        // `simctl uninstall`/install while Documents is wiped — plus
        // theoretical prod edge cases: Files.app delete, storage-
        // pressure eviction, partial CloudKit restore). Validate
        // against the store; nil any whose file is missing so the
        // `handleProfilePictureRowTap` conditional + every consumer
        // sees the corrected state. Next `handleSave()` persists the
        // cleared state — the inconsistency self-heals permanently.
        // `.task` (not `.onAppear`) for the async `exists` check.
        .task {
            guard let photoStore else { return }
            let validated = await Self.validatePhotoReferences(
                photoFilename: inFlightPhotoFilename,
                photoOriginalFilename: inFlightPhotoOriginalFilename,
                photoStore: photoStore
            )
            inFlightPhotoFilename = validated.photoFilename
            inFlightPhotoOriginalFilename = validated.photoOriginalFilename
        }
        #endif
    }

    // Cross-file splits (all for the SwiftLint file_length / type_body_length
    // caps; the non-`private` `@State` vars above exist so these satellites can
    // read/write them):
    // - `isDirty` / `computeIsDirty(...)` / `toolbarContent` → `+DirtyState.swift` (T-743 / CL-140).
    // - `signOutSection` + `profileStatsSection` (DUT-417) → `+SignOut.swift` / `+Stats.swift`.
    // - `isFormValid` + per-field errors (DUT-414 / DUT-415) → `+Validation.swift`.
    // - `handleSave()` → `+Save.swift` (T-745 / CL-142).
    // - `handleSignOut()` / `handleDelete()` / `teardown(revoke:)` → `+Teardown.swift` (DUT-217).
    // - Photo handlers (`loadPickedImage` / `handleCroppedImage` / `handleRemovePhoto`) → `+Photo.swift`.
}
