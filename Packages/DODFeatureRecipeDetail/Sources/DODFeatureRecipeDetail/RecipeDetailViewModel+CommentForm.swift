import DODSupport
import Foundation

// DUT-28 / DUT-605 — the consolidated rate + review form's field binders and the
// guest-identity prefill / persist. Extracted from `RecipeDetailViewModel.swift`
// so that file stays under the SwiftLint 400-line `file_length` cap (same
// partitioning as `+CommentSubmit` / `+RatingSubmit` / `+Fetch`).

extension RecipeDetailViewModel {

    /// DUT-605 — hard cap on the in-app comment draft length (chars). WordPress
    /// accepts long comments, but an unbounded `TextEditor` lets a paste dump a
    /// runaway body onto the section; 1000 chars is generous for a recipe review
    /// while keeping the POST + the rendered row sane. The ratings section shows
    /// a live counter and gates Submit on this.
    public static let commentDraftCharacterLimit = 1000

    public func setCommentDraft(_ text: String) {
        // DUT-605: clamp to the cap so even a large paste can't exceed it. Prefix
        // keeps the leading (already-typed) content and drops the overflow tail.
        if text.count > Self.commentDraftCharacterLimit {
            commentDraft = String(text.prefix(Self.commentDraftCharacterLimit))
        } else {
            commentDraft = text
        }
    }

    /// DUT-28 — bind the on-form "Display name" field.
    public func setCommentAuthorName(_ name: String) {
        commentAuthorName = name
    }

    /// DUT-28 — bind the on-form "Email" field.
    public func setCommentAuthorEmail(_ email: String) {
        commentAuthorEmail = email
    }

    /// DUT-28 — seed ``commentAuthorName`` + ``commentAuthorEmail`` from the
    /// saved guest identity so a returning commenter sees their details
    /// pre-filled on the form. Leaves the fields empty if nothing is saved.
    /// Only seeds a field the user hasn't already typed into this session,
    /// so a late background refresh never clobbers in-progress edits.
    public func prefillAuthorIdentity() async {
        guard let identity = await dependencies.loadGuestIdentity() else { return }
        if commentAuthorName.isEmpty {
            commentAuthorName = identity.name
        }
        if commentAuthorEmail.isEmpty {
            commentAuthorEmail = identity.email
        }
    }

    /// DUT-28 — persist the on-form display name + email to the Keychain so
    /// the next visit pre-fills them. Best-effort: a Keychain write failure
    /// is logged and surfaced but never blocks the comment/rating POST the
    /// caller is about to make (the values are still valid in memory).
    func persistAuthorIdentity(name: String, email: String) async {
        do {
            try await dependencies.saveGuestIdentity(name: name, email: email)
        } catch {
            DODLog.persistence.error("save guest identity failed: \(String(describing: error))")
            snackbarMessage = "Couldn't save your name. We'll still post your comment."
        }
    }
}
