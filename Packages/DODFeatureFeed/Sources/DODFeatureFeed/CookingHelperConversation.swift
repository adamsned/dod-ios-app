import DODDesignSystem
import SwiftUI

/// One row in the "Ask Dutch Oven Daddy" conversation. DUT-2893 — the look
/// itself is the shared ``DODChatMessageRow`` (DODDesignSystem), so every
/// on-device chat renders identically.
struct CookingHelperTurnView: View {

    let turn: CookingHelperViewModel.Turn

    var body: some View {
        DODChatMessageRow(
            isUser: turn.role == .user,
            text: turn.text,
            hasImage: turn.hasImage,
            isMuted: turn.isEmptyResult
        )
    }
}
