import DODPersistence
import DODSupport
import PhotosUI
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Behavior helpers for ``FirstCookoutView`` — the cook-logging + photo/timer
/// side-effects (US-53 / DUT-104 / DUT-209 / DUT-548), extracted here so the
/// main flow file stays under the SwiftLint `file_length` / `type_body_length`
/// caps (which DUT-548's host-owned dedup + DUT-209's off-main writer pushed it
/// over). Members are `internal` (not `private`) so `body` in the main file can
/// still invoke them across the extension boundary.
extension FirstCookoutView {

    /// Advances the timer engine ~1×/s while the flow is on screen so the bake
    /// countdown ticks down and finishes. A cheap no-op when no timer runs.
    func runTimerTick() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            timerEngine.refresh()
        }
    }

    func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        cookPhotoData = data
        #if canImport(UIKit)
        if let uiImage = UIImage(data: data) {
            cookPhoto = Image(uiImage: uiImage)
        }
        #endif
    }

    /// Log the completed cook exactly once (DUT-104) — fired on "Done" so the
    /// journal records "I made the lasagna today", feeding streaks/stats.
    func logCookIfNeeded() {
        // DUT-548 — dedup across a "Back to the path" → re-enter cycle. The
        // per-view `hasLoggedCook` resets when this view is rebuilt, so on its own
        // it can't stop a second log for the SAME rung minutes later (past the
        // persistence ±3s window, DUT-484/495). The host-owned `loggedRecipeIDs`
        // set (keyed by recipeID, matching DUT-547) survives the rebuild, so a
        // re-entered rung is recognised as already logged. Both guards preserved:
        // `hasLoggedCook` still stops a same-lifecycle double-tap / onDisappear
        // race for unwired hosts (nil binding).
        guard !hasLoggedCook, !loggedRecipeIDs.contains(cookout.recipeID) else { return }
        hasLoggedCook = true
        loggedRecipeIDs.insert(cookout.recipeID)
        let photoID = savePhotoOffMain()
        // DUT-324 — carry the written reflection through as the cook's note.
        let trimmedReflection = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
        onLogCook?(
            CookLogEntry(
                id: UUID(),
                recipeID: cookout.recipeID,
                recipeTitle: cookout.dishTitle,
                cookedAt: .now,
                note: trimmedReflection.isEmpty ? nil : trimmedReflection,
                photoLocalID: photoID
            )
        )
    }

    /// DUT-209 — persist the celebration photo OFF the main thread so the atomic
    /// full-resolution JPEG write doesn't hitch the "Done" dismiss. Pre-mints the
    /// photo id + filename synchronously (returned so the entry references it
    /// optimistically), then flushes the bytes on a detached executor via the
    /// injected `photoWriter`. On a disk failure the DUT-312 snackbar still
    /// surfaces (the continuation hops back to the main actor); the journal's
    /// photo load degrades gracefully (a missing file reads as no photo), so the
    /// entry keeps the filename but the cook itself is never lost. Returns `nil`
    /// when there's no photo to save.
    private func savePhotoOffMain() -> String? {
        guard let photoData = cookPhotoData else { return nil }
        let id = UUID().uuidString
        let writer = photoWriter
        // `writer.save` is `nonisolated async`, so its blocking file write runs
        // OFF the main actor even though this `Task` is spawned from one; the
        // continuation hops back to the main actor to surface any DUT-312 error,
        // so mutating the `@State` `photoSaveError` here is safe.
        Task {
            do {
                _ = try await writer.save(photoData, id: id)
            } catch {
                photoSaveError =
                    "Your cook is logged, but we couldn't save the photo. Try again from your journal."
            }
        }
        return "\(id).jpg"
    }

    func stageIcon(_ stage: GuidedCookout.Stage) -> String {
        switch stage {
        case .gather: return "checklist"
        case .fire: return "flame.fill"
        case .cook: return "frying.pan.fill"
        case .celebrate: return "party.popper.fill"
        }
    }
}
