import DODDesignSystem
import SwiftUI

/// Pure row model so the logic is testable without rendering.
public struct ServeActivityRow: Hashable, Identifiable, Sendable {
    public enum Phase: Sendable { case upcoming, cooking }
    public let id: Int
    public let title: String
    public let phase: Phase
    public let target: Date  // cookStart when upcoming, serveAt when cooking
}

public func serveActivityRows(
    state: ServeActivityAttributes.ContentState,
    now: Date
) -> [ServeActivityRow] {
    state.dishes.map { dish in
        dish.cookStart > now
            ? ServeActivityRow(id: dish.id, title: dish.title, phase: .upcoming, target: dish.cookStart)
            : ServeActivityRow(id: dish.id, title: dish.title, phase: .cooking, target: dish.serveAt)
    }
}

public struct ServeActivityLockScreenView: View {
    let title: String
    let state: ServeActivityAttributes.ContentState
    public init(title: String, state: ServeActivityAttributes.ContentState) {
        self.title = title
        self.state = state
    }
    public var body: some View {
        let now = Date()
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if state.isCompleted {
                    Text("Served!")
                } else if state.serveAt > now {
                    Text(timerInterval: now...state.serveAt, countsDown: true).monospacedDigit()
                }
            }
            ForEach(serveActivityRows(state: state, now: now)) { row in
                HStack {
                    Text(row.title).lineLimit(1)
                    Spacer()
                    Text(row.phase == .upcoming ? "Start in" : "Ready in").font(.caption)
                    if row.target > now { Text(timerInterval: now...row.target, countsDown: true).monospacedDigit() }
                }
            }
        }
    }
}
