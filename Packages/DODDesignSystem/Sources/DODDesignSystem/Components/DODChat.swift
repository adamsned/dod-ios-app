import SwiftUI

// DUT-2893 — the shared look of the on-device chats ("Ask Dutch Oven Daddy",
// "Ask the Recipe", Cook Mode's recipe chat). Lifted out of the Feed package's
// `CookingHelper*` views so every chat renders from the same pieces instead of
// drifting copies. Each piece is presentation only; the sheets own the state.

/// One conversation row: a right-aligned orange user bubble, or a left-aligned
/// assistant card labeled "Dutch Oven Daddy".
public struct DODChatMessageRow: View {

    let isUser: Bool
    let text: String
    let hasImage: Bool
    /// Assistant text in the secondary color (an "I couldn't answer" result).
    let isMuted: Bool

    public init(isUser: Bool, text: String, hasImage: Bool = false, isMuted: Bool = false) {
        self.isUser = isUser
        self.text = text
        self.hasImage = hasImage
        self.isMuted = isMuted
    }

    public var body: some View {
        if isUser { userBubble } else { assistantCard }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: DODSpacing.xl)
            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                if hasImage {
                    Label("Photo attached", systemImage: "photo")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelOnAccent.opacity(0.9))
                }
                if !text.isEmpty {
                    Text(text)
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.labelOnAccent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, DODSpacing.md)
            .padding(.vertical, DODSpacing.sm)
            .background(DODColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You asked: \(hasImage ? "with a photo. " : "")\(text)")
    }

    private var assistantCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: DODSpacing.xs) {
                Label {
                    Text("Dutch Oven Daddy")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.accent)
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(DODColor.accent)
                }
                Text(text)
                    .dodFont(DODType.body)
                    .foregroundStyle(isMuted ? DODColor.labelSecondary : DODColor.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DODSpacing.md)
            .background(DODColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
            Spacer(minLength: DODSpacing.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dutch Oven Daddy answered: \(text)")
    }
}

/// The "Thinking…" row shown while an answer is in flight.
public struct DODChatThinkingRow: View {

    public init() {}

    public var body: some View {
        HStack(spacing: DODSpacing.sm) {
            ProgressView()
                .tint(DODColor.accent)
            Text("Thinking…")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
            Spacer(minLength: 0)
        }
        .padding(DODSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Thinking")
    }
}

/// The centered sparkles + title + message shown before the first question.
public struct DODChatEmptyState: View {

    let title: String
    let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: DODSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(DODColor.accent)
            Text(title)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
                .multilineTextAlignment(.center)
            Text(message)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DODSpacing.md)
    }
}

/// A horizontally scrolling row of suggested questions (capsule chips). Hidden
/// when there's nothing to suggest.
public struct DODChatSuggestionChips: View {

    let suggestions: [String]
    let isDisabled: Bool
    let onSelect: (String) -> Void

    public init(suggestions: [String], isDisabled: Bool, onSelect: @escaping (String) -> Void) {
        self.suggestions = suggestions
        self.isDisabled = isDisabled
        self.onSelect = onSelect
    }

    public var body: some View {
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DODSpacing.xs) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            onSelect(suggestion)
                        } label: {
                            Text(suggestion)
                                .dodFont(DODType.body)
                                .foregroundStyle(DODColor.accent)
                                .padding(.horizontal, DODSpacing.md)
                                .padding(.vertical, DODSpacing.xs)
                                .background(Capsule().fill(DODColor.accent.opacity(0.15)))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isDisabled)
                        .opacity(isDisabled ? 0.5 : 1)
                        .accessibilityHint("Asks this question")
                    }
                }
                .padding(.horizontal, DODSpacing.md)
            }
            .accessibilityIdentifier("dod.chat.suggestions")
        }
    }
}

/// The rounded question field with the round send button inside it.
public struct DODChatField: View {

    let placeholder: String
    @Binding var text: String
    let canSend: Bool
    let fieldIdentifier: String
    let sendIdentifier: String
    let onSend: () -> Void

    public init(
        placeholder: String,
        text: Binding<String>,
        canSend: Bool,
        fieldIdentifier: String = "dod.chat.field",
        sendIdentifier: String = "dod.chat.send",
        onSend: @escaping () -> Void
    ) {
        self.placeholder = placeholder
        self._text = text
        self.canSend = canSend
        self.fieldIdentifier = fieldIdentifier
        self.sendIdentifier = sendIdentifier
        self.onSend = onSend
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: DODSpacing.xxs) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...5)
                .dodFont(DODType.body)
                .textFieldStyle(.plain)
                .padding(.leading, DODSpacing.md)
                .padding(.vertical, DODSpacing.sm)
                .accessibilityIdentifier(fieldIdentifier)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(canSend ? DODColor.accent : DODColor.labelSecondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .padding(.trailing, DODSpacing.xxs)
            .padding(.bottom, DODSpacing.xxs)
            .accessibilityIdentifier(sendIdentifier)
            .accessibilityLabel("Send")
        }
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
    }
}

/// The small "can make mistakes" line under the input.
public struct DODChatDisclaimer: View {

    public init() {}

    public var body: some View {
        Text("Dutch Oven Daddy can make mistakes. Double-check important cooking info.")
            .dodFont(DODType.caption)
            .foregroundStyle(DODColor.labelSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DODSpacing.lg)
            .padding(.bottom, DODSpacing.xs)
            .frame(maxWidth: .infinity)
            .background(DODColor.surface)
    }
}
