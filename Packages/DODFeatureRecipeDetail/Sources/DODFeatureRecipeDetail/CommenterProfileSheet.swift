import DODDesignSystem
import DODDomain
import SwiftUI

/// DUT-956 — the "commenter card": a tappable profile sheet for ANOTHER user's
/// comment, reached by tapping their avatar or name in the ratings/reviews list.
///
/// This promotes the previously-hidden long-press `.contextMenu` Report/Block
/// (in ``RecipeDetailRatingsSection/commentRow(for:)``) into a real, discoverable
/// page. It reuses the SAME moderation methods the context menu calls — nothing
/// about the Report/Block semantics changes; only the entry point becomes visible:
/// - **Report** runs the section's `reportAndOpenMail(for:)` (hide locally +
///   open the prefilled moderation `mailto:` + `acknowledgeReport`), wired in via
///   `onReport` so the sheet opens the email through the exact same path.
/// - **Block** runs `RecipeDetailViewModel.blockAuthor(of:)` via `onBlock`.
/// Report fires immediately (single-comment scope, mirrors the long-press
/// path). Block on a NAMED author confirms first — it hides every comment
/// from that person, app-wide and going forward, with no in-app Unblock (it
/// only clears via Sign Out / Delete Profile) — the same "irreversible,
/// app-wide" class of action that gets a confirm dialog everywhere else in
/// the app (Sign Out, Delete Profile, Clear Shopping List, Clear Recent
/// Searches). The blank-name ("Anonymous") fallback stays immediate — it
/// only hides the one comment, the same blast radius as Report. This
/// mirrors the context menu's own gate (``RecipeDetailRatingsSection``'s
/// `pendingBlockComment` / `requestBlock(of:)`) — same confirm-before-
/// author-block rule, independent local state per entry point.
///
/// **Layout mirrors the profile editor's shape** (``ProfileEditView``) so the
/// per-user stats from DUT-955 drop straight in: a centered avatar + name header,
/// then a "Cook Stats" section (an honest empty placeholder today — the future
/// Cook Rank + stat tiles live here), then the Report / Block actions in the
/// editor's Sign Out / Delete position. We NEVER show an email (other users'
/// comments never carry one — see ``RecipeComment/authorEmail``).
///
/// Spec trace: social-layer.md "Near-term win (no backend) — DUT-956"; upgrades
/// into DUT-955 (Commenter profiles + public stats API) once the backend lands.
struct CommenterProfileSheet: View {

    /// The tapped comment. Carries the avatar URL + author name the card renders,
    /// and is the argument the reused moderation closures act on.
    let comment: RecipeComment
    /// Pre-resolved display name (blank authors already mapped to "Anonymous" by
    /// the caller) so the sheet and the block affordance agree on the name.
    let displayName: String
    /// Reuse hook — the section's `reportAndOpenMail(for:)`, so Report opens the
    /// moderation `mailto:` and calls `acknowledgeReport` on the same path the
    /// long-press context menu uses.
    let onReport: () -> Void
    /// Reuse hook — `RecipeDetailViewModel.blockAuthor(of:)`.
    let onBlock: () -> Void

    @Environment(\.dismiss) private var dismiss
    /// Gates the "Block This Person?" confirmation for a named author — see
    /// the type doc comment above for why. Local to this sheet (independent
    /// of the context menu's own `pendingBlockComment` gate on
    /// ``RecipeDetailRatingsSection``): each entry point hosts its own
    /// confirm, mirroring how `CookJournalView` and `CookJournalEntryView`
    /// each host their own "Delete This Cook?" alert for the same delete.
    @State private var showingBlockConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                statsPlaceholderSection
                reportSection
                blockSection
            }
            .scrollContentBackground(.hidden)
            .background(DODColor.surface)
            .navigationTitle("Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            .alert("Block This Person?", isPresented: $showingBlockConfirmation) {
                Button("Block", role: .destructive) {
                    onBlock()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "This hides every comment from \(displayName) here, now and going forward. "
                        + "There's no in-app way to undo this."
                )
            }
        }
    }

    // MARK: - Toolbar

    /// Repo nav rule: sheets dismiss via a "Done" button top-right (pushes use a
    /// chevron). `.confirmationAction` resolves to the trailing slot on iOS and is
    /// cross-platform (no `.topBarTrailing`, which fails the macOS L1 compile).
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
        }
    }

    // MARK: - Header (avatar + name)

    private var headerSection: some View {
        Section {
            VStack(spacing: DODSpacing.sm) {
                avatar
                Text(displayName)
                    .dodFont(DODType.displayMedium)
                    .foregroundStyle(DODColor.labelStrong)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DODSpacing.sm)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(displayName)
        }
        .listRowBackground(DODColor.surfaceElevated)
    }

    /// 72pt circular avatar — the same Gravatar-via-`AsyncImage` path
    /// ``CommentRow`` uses, with the identical SF-symbol placeholder fallback.
    @ViewBuilder
    private var avatar: some View {
        AsyncImage(url: comment.avatarURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .empty, .failure:
                avatarFallback
            @unknown default:
                avatarFallback
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var avatarFallback: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(DODColor.labelSecondary)
            .frame(width: 72, height: 72)
    }

    // MARK: - Cook Stats placeholder (DUT-955 drops in here)

    /// The honest empty state that reserves the spot the per-user stats (Cook Rank
    /// + stat tiles, DUT-955) will fill once the public-stats backend exists. Kept
    /// tasteful — a section header + one-line caption, not a banner.
    private var statsPlaceholderSection: some View {
        Section {
            Text("Cook stats will appear here soon.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, DODSpacing.xs)
        } header: {
            Text("Cook Stats")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .listRowBackground(DODColor.surfaceElevated)
    }

    // MARK: - Actions (Report / Block — the editor's Sign Out / Delete slot)

    /// Report sits in the friendlier "Sign Out" position (accent). Dismisses after
    /// firing so the user returns to the list (the comment is now hidden locally,
    /// and Report opens the Mail app anyway).
    private var reportSection: some View {
        Section {
            Button {
                onReport()
                dismiss()
            } label: {
                Label("Report Comment", systemImage: "flag")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("commenter-profile-report")
        }
        .listRowBackground(DODColor.surfaceElevated)
    }

    /// Block sits in the destructive "Delete Profile" position. The label
    /// mirrors the context menu's `blockLabel(for:)` — anonymous authors can't
    /// be name-blocked, so the button says "Hide Comment" to describe what
    /// actually happens. A named-author block confirms first (single-comment
    /// scope stays immediate, matching Report); either way the sheet dismisses
    /// once the action actually runs.
    private var blockSection: some View {
        Section {
            Button(role: .destructive) {
                if blockRequiresConfirmation {
                    showingBlockConfirmation = true
                } else {
                    onBlock()
                    dismiss()
                }
            } label: {
                Label(blockLabel, systemImage: "hand.raised")
                    .dodFont(DODType.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("commenter-profile-block")
        }
        .listRowBackground(DODColor.surfaceElevated)
    }

    /// Whether a Block tap on this comment should confirm first (a named
    /// author — permanent, app-wide) or fire immediately (the blank-name
    /// fallback — single-comment scope, same blast radius as Report).
    /// Extracted from the button action so the branch is directly testable
    /// without simulating a tap gesture. Non-private for that reason (mirrors
    /// `RecipeDetailRatingsSection.pendingBlockComment`'s non-private note).
    var blockRequiresConfirmation: Bool {
        !CommentModerationStore.isAnonymous(author: comment.authorName)
    }

    private var blockLabel: String {
        CommentModerationStore.isAnonymous(author: comment.authorName)
            ? "Hide Comment"
            : "Block \(displayName)"
    }
}

#Preview("Commenter profile (DUT-956)") {
    CommenterProfileSheet(
        comment: RecipeComment(
            id: 4242,
            postID: 902,
            authorName: "Jamie L.",
            avatarURL: nil,
            dateGMT: Date(timeIntervalSince1970: 1_700_000_000),
            body: "Made this last night and it was incredible.",
            ratingValue: 5,
            status: .approved
        ),
        displayName: "Jamie L.",
        onReport: {},
        onBlock: {}
    )
}
