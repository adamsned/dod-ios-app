import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-981 — pure draft state so validation is unit-testable.
struct GuestReactionDraft: Equatable {
    var quote = ""
    var guestName = ""
    var rating = 0  // 0 == no stars

    var isValid: Bool {
        GuestReactionFormatter.commentBody(quote: quote, guestName: guestName, hostName: "") != nil
    }

    var ratingToSend: Int? { rating > 0 ? min(5, rating) : nil }
}

/// DUT-981 — self-contained sheet where the host records what a guest said
/// in person, the guest's name, and an optional 1–5 star rating. Mirrors
/// `CookModeJournalLogSheet`'s toolbar and Cancel/Save conventions.
struct GuestReactionSheet: View {

    /// Called on Post with (quote, guestName, rating). Returns true on success so the sheet can dismiss.
    let onPost: (String, String, Int?) async -> Bool

    @State private var draft = GuestReactionDraft()
    @State private var isPosting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("What did your guest say?") {
                    TextField("\u{201C}This was amazing\u{201D}", text: $draft.quote, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("guest-reaction-quote")
                    TextField("Guest's name", text: $draft.guestName)
                        .accessibilityIdentifier("guest-reaction-name")
                }
                Section("Rating (optional)") {
                    Stepper("Stars: \(draft.rating)", value: $draft.rating, in: 0...5)
                        .accessibilityIdentifier("guest-reaction-rating")
                }
                Section {
                    Text("This posts publicly on the recipe under your name, crediting your guest.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Share the Praise")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(DODColor.label)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { post() }
                        .tint(DODColor.burntOrange)
                        .disabled(!draft.isValid || isPosting)
                        .accessibilityIdentifier("guest-reaction-post")
                }
            }
        }
    }

    private func post() {
        isPosting = true
        let current = draft
        Task {
            let ok = await onPost(current.quote, current.guestName, current.ratingToSend)
            isPosting = false
            if ok { dismiss() }
        }
    }
}
