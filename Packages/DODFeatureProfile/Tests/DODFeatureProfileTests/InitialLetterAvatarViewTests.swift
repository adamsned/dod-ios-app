import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 coverage for the initial-letter extraction rules driving
/// ``InitialLetterAvatarView``. The view's snapshot register (color +
/// font scale) is locked separately in `InitialLetterAvatarViewSnapshotTests`
/// (L4, UIKit-gated); these unit tests pin the pure-Swift letter
/// extraction so a future refactor of the view body can't silently
/// regress the empty / emoji-prefix / fallback paths.
///
/// Spec trace: US-44 AC-44.5; CL-136.
@Suite("InitialLetterAvatarView (T-739)")
struct InitialLetterAvatarViewTests {

    @Test func singleLetterNameSurfacesUppercase() {
        let initial = InitialLetterAvatarView.initialLetter(from: "a")
        #expect(initial == "A")
    }

    @Test func twoWordNameUsesFirstWordsFirstLetter() {
        let initial = InitialLetterAvatarView.initialLetter(from: "Spencer Adams")
        #expect(initial == "S")
    }

    @Test func emojiPrefixSkipsToFirstLetter() {
        // "🌟 Spencer" → strip the star + space, take "S".
        let initial = InitialLetterAvatarView.initialLetter(from: "🌟 Spencer")
        #expect(initial == "S")
    }

    @Test func allEmojiNameFallsBackToQuestionMark() {
        let initial = InitialLetterAvatarView.initialLetter(from: "🌟🍳🔥")
        #expect(initial == "?")
    }

    @Test func emptyNameFallsBackToQuestionMark() {
        let initial = InitialLetterAvatarView.initialLetter(from: "")
        #expect(initial == "?")
    }

    @Test func whitespaceOnlyNameFallsBackToQuestionMark() {
        let initial = InitialLetterAvatarView.initialLetter(from: "   \t  ")
        #expect(initial == "?")
    }

    @Test func lowercaseNameUppercasesTheInitial() {
        let initial = InitialLetterAvatarView.initialLetter(from: "ned")
        #expect(initial == "N")
    }

    @Test func leadingDigitsSkipToFirstLetter() {
        // "3 Spencer" → digits are non-letter, so the search lands on "S".
        let initial = InitialLetterAvatarView.initialLetter(from: "3 Spencer")
        #expect(initial == "S")
    }

    @Test func leadingPunctuationSkipsToFirstLetter() {
        let initial = InitialLetterAvatarView.initialLetter(from: ".-_Sam")
        #expect(initial == "S")
    }
}
