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
}
