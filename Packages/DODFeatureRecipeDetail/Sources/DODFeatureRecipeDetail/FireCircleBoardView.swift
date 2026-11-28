import DODSupport
import Foundation
import SwiftUI

/// DUT-2902 - the Fire Circle board: one row per peer's cook.
struct FireCircleBoardView: View {
    let board: FireCircleBoard

    var body: some View {
        Text("Fire Circle")
    }

    /// m:ss under an hour, h:mm:ss otherwise.
    nonisolated static func clock(_ seconds: Int) -> String {
        CampfireTimerReadout.format(seconds: seconds)
    }

    /// Row label: Done, Paused, or the live countdown.
    nonisolated static func status(for cook: FireCircleCook, now: Date) -> String {
        if cook.isCompleted { return "Done" }
        if cook.isPaused { return "Paused" }
        return clock(cook.remaining(now: now))
    }
}
