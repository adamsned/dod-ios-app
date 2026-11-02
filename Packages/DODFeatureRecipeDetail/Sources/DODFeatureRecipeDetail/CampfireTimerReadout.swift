import Foundation

/// DUT-102 - what the Campfire Mode big timer readout shows.
enum CampfireTimerReadout {
    /// m:ss under an hour, h:mm:ss otherwise.
    static func format(seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Prefers the current step's timer; otherwise the running timer that ends
    /// soonest. Returns nil when there is nothing to show. Idle timers are ignored.
    static func text(
        timers: [Int: CookStepTimer],
        currentStep: Int,
        now: Date
    ) -> String? {
        if let own = timers[currentStep], own.state != .idle {
            return format(seconds: own.remaining(at: now))
        }
        let soonest = timers.values
            .filter { $0.isRunning }
            .map { $0.remaining(at: now) }
            .min()
        return soonest.map(format(seconds:))
    }
}
