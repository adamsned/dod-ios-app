import DODSupport
import Foundation

/// DUT-104 / DUT-323 / DUT-339 — the rank-up / graduation celebration logic
/// for ``FeedViewModel``, extracted here so the main view-model file stays
/// under the SwiftLint `file_length` cap (mirrors the `+Journal` /
/// `+SaveToggle` / `+ShoppingList` splits). The `celebration` /
/// `pendingCelebration` / `cookoutSheetVisible` stored state stays in the main
/// file (extensions can't add stored properties); those were widened to
/// `internal` so this extension can reach them.
extension FeedViewModel {

    /// DUT-104 — record a completed cook in the private journal (called when the
    /// "Your First Cookout" flow reaches "Done"). A failed write must never
    /// BLOCK dismissing the celebration flow, but (mirrors PR #744 / DUT-694)
    /// it must not vanish silently either — see `cookLogFailureMessage` below.
    /// DUT-323: if the cook graduates the path or bumps the cook up a rank,
    /// queue the celebration.
    public func logCook(_ entry: CookLogEntry) async {
        let logsBefore = (try? await dependencies.cookLogs()) ?? []
        do {
            try await dependencies.logCook(entry)
        } catch {
            // The write failing must never block the flow from finishing — but
            // a bare swallow left the user with zero feedback that their "I
            // made this" record didn't land. Mirrors PR #744
            // (`RecipeDetailViewModel.toggleSaved()`) and DUT-694's
            // `updateCook`/`deleteCook`: surface it instead of only logging.
            cookLogFailureMessage = "Couldn't save your cook — try logging it again from the Cooking Journal."
            // DUT-208: the caller wrote the photo JPEG to disk before this call,
            // so a failed write would orphan it (no row ever references its
            // `photoLocalID`). Delete it here, mirroring the DUT-423 dedup-branch
            // cleanup in RecipeStore+CookLog.
            if let photoID = entry.photoLocalID {
                await dependencies.deleteCookPhoto(id: photoID)
            }
            return
        }
        let logsAfter = (try? await dependencies.cookLogs()) ?? logsBefore
        let cookedBefore = Set(logsBefore.map(\.recipeID))
        let cookedAfter = Set(logsAfter.map(\.recipeID))
        // Graduating the whole First Cookout path is the bigger beat → priority.
        let wasGraduate = GuidedCookout.nextUncookedRung(cookedRecipeIDs: cookedBefore) == nil
        let isGraduate = GuidedCookout.nextUncookedRung(cookedRecipeIDs: cookedAfter) == nil
        if isGraduate && !wasGraduate {
            pendingCelebration = .graduatedFirstCookout
        } else if !OwnerGate.isCurrentUserOwner() {
            // Daddy Mode (owner rank) — the owner's rank is fixed at "The Dutch Oven
            // Daddy", so he never "ranks up". Suppress the rank-up celebration for
            // him (a "You're a Cast Iron Legend" beat would contradict his rank).
            let reached = CookProgression.rankUp(
                from: Self.rankLadderCookCount(logsBefore),
                to: Self.rankLadderCookCount(logsAfter)
            )
            if let reached {
                pendingCelebration = .rankUp(reached)
            }
        }
        promoteCelebrationIfReady()
    }

    /// DUT-339 — the cookout flow's sheet is presenting; defer any pending
    /// celebration until it dismisses so the two sheets never overlap.
    public func cookoutFlowWillPresent() {
        cookoutSheetVisible = true
    }

    /// DUT-339 — the cookout flow's sheet finished dismissing; a queued
    /// celebration can present now without a sheet-over-sheet conflict.
    public func cookoutFlowDidDismiss() {
        cookoutSheetVisible = false
        promoteCelebrationIfReady()
    }

    /// Promote a queued celebration once the cookout sheet is gone — called from
    /// both `logCook` and `cookoutFlowDidDismiss`, so whichever finishes last
    /// triggers the present (DUT-339).
    func promoteCelebrationIfReady() {
        guard !cookoutSheetVisible, let pending = pendingCelebration else { return }
        celebration = pending
        pendingCelebration = nil
    }

    /// Dismiss the celebration (DUT-323).
    public func dismissCelebration() {
        celebration = nil
    }

    /// Dismiss the cook-log failure snackbar (auto-dismiss timer, or a tap) —
    /// mirrors `dismissShoppingListSnackbar()` in `FeedViewModel+ShoppingList`.
    public func dismissCookLogFailureMessage() {
        cookLogFailureMessage = nil
    }
}
