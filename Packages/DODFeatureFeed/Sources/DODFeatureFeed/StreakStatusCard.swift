import DODSupport
import SwiftUI

/// DUT-972 — pure copy for the home streak card, kept separate from the view so it is testable.
public struct StreakStatusSummary: Equatable {
    public let headline: String
    public let detail: String

    public init(status: StreakNudge.Status) {
        switch status {
        case .safe(let streak):
            headline = "\(streak)-week streak"
            detail = "You're covered this week. Nice work."
        case .atRisk(let streak):
            headline = "\(streak)-week streak — still alive"
            detail = StreakNudge.content(for: status)?.smallestNextRep ?? ""
        case .none:
            headline = "Start a streak"
            detail = "One skillet dish this week gets it going."
        }
    }
}

public struct StreakStatusCard: View {
    private let summary: StreakStatusSummary

    public init(status: StreakNudge.Status) {
        summary = StreakStatusSummary(status: status)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.headline).font(.headline)
            Text(summary.detail).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .accessibilityElement(children: .combine)
    }
}
