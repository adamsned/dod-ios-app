import SwiftUI

/// Auto-dismissing bottom snackbar. Optional Undo button on the trailing edge.
/// Default dismiss time is 4 seconds.
///
/// Used for save/unsave undo (AC-5.1) and "Recipe unavailable" (AC-4.11).
public struct Snackbar: View {

    public struct Action {
        public let title: String
        public let handler: @MainActor () -> Void
        public init(title: String, handler: @MainActor @escaping () -> Void) {
            self.title = title
            self.handler = handler
        }
    }

    public let message: String
    public let action: Action?

    /// Bumped once on appear so `.sensoryFeedback` fires a subtle light tap
    /// for every fresh snackbar presentation, even if the message text is
    /// identical to a previously shown one.
    @State private var appearanceTrigger: Int = 0

    public init(message: String, action: Action? = nil) {
        self.message = message
        self.action = action
    }

    public var body: some View {
        HStack(spacing: DODSpacing.md) {
            Text(message)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.cream)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let action {
                Button(action.title, action: action.handler)
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.warmGold)
            }
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                .fill(DODColor.castIronBrown)
        )
        .padding(.horizontal, DODSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(action.map { "\(message). \($0.title) available." } ?? message)
        .sensoryFeedback(.impact(weight: .light), trigger: appearanceTrigger)
        .onAppear { appearanceTrigger &+= 1 }
    }
}

#Preview("Plain") {
    Snackbar(message: "Recipe unavailable.")
}

#Preview("With Undo") {
    Snackbar(message: "Removed from saved.", action: .init(title: "Undo") {})
}
