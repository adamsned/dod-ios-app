import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-604 — Tests for `SystemCookStepTimerNotifier.identifier(recipeID:stepIndex:)`.
/// This pure static function builds notification IDs in format:
/// "dod.cookMode.stepTimerDone.<recipeID>.<stepIndex>".
///
/// The identifier format is critical because `cancelAllStepDone(recipeID:)` relies on
/// prefix matching (`"\(Self.identifier).\(recipeID)."`) to filter notifications.
/// If the format ever changes (e.g., removing the dot separator), it could silently
/// break the whole-recipe cancel or create false cross-recipe collisions.
/// These tests pin down the exact format and prefix-matching behavior.
@Suite("SystemCookStepTimerNotifier.identifier (DUT-604)") @MainActor struct CookStepTimerNotifierIDTests {

    /// Basic format validation: ensure identifier produces the exact expected string.
    /// Recipe 42, step 0 should produce "dod.cookMode.stepTimerDone.42.0".
    @Test func basicFormatValidation() {
        let result = SystemCookStepTimerNotifier.identifier(recipeID: 42, stepIndex: 0)
        #expect(result == "dod.cookMode.stepTimerDone.42.0")
    }

    /// Different recipe/step combinations must produce different identifiers.
    /// Ensures that (1, 2) ≠ (2, 1) — order matters, no accidental collision from swapped args.
    @Test func differentCombosProduceDifferentIdentifiers() {
        let id1And2 = SystemCookStepTimerNotifier.identifier(recipeID: 1, stepIndex: 2)
        let id2And1 = SystemCookStepTimerNotifier.identifier(recipeID: 2, stepIndex: 1)
        #expect(id1And2 != id2And1)
    }

    /// Cross-recipe prefix collision guard (the subtle bug this test prevents).
    /// Recipe 5's identifiers must NOT be caught by recipe 50's prefix filter.
    /// Since `cancelAllStepDone(50)` uses prefix `"dod.cookMode.stepTimerDone.50."`,
    /// recipe 5's identifiers (which use `"dod.cookMode.stepTimerDone.5.<stepIndex>"`)
    /// must not match that prefix, and vice versa.
    @Test func crossRecipePrefixCollisionGuard() {
        let id5Step2 = SystemCookStepTimerNotifier.identifier(recipeID: 5, stepIndex: 2)
        let id50Step1 = SystemCookStepTimerNotifier.identifier(recipeID: 50, stepIndex: 1)

        // Recipe 5's identifier should NOT match recipe 50's whole-recipe prefix.
        #expect(!id5Step2.hasPrefix("dod.cookMode.stepTimerDone.50."))

        // Recipe 50's identifier SHOULD match recipe 50's whole-recipe prefix.
        #expect(id50Step1.hasPrefix("dod.cookMode.stepTimerDone.50."))
    }

    /// Same recipeID, all steps share the whole-recipe prefix.
    /// `cancelAllStepDone(5)` filters by prefix `"dod.cookMode.stepTimerDone.5."`,
    /// so identifiers for steps 0, 1, and 99 of recipe 5 must all match that prefix.
    @Test func sameRecipeIDAllStepsSharePrefix() {
        let step0 = SystemCookStepTimerNotifier.identifier(recipeID: 5, stepIndex: 0)
        let step1 = SystemCookStepTimerNotifier.identifier(recipeID: 5, stepIndex: 1)
        let step99 = SystemCookStepTimerNotifier.identifier(recipeID: 5, stepIndex: 99)

        let expectedPrefix = "dod.cookMode.stepTimerDone.5."
        #expect(step0.hasPrefix(expectedPrefix))
        #expect(step1.hasPrefix(expectedPrefix))
        #expect(step99.hasPrefix(expectedPrefix))
    }

    /// Edge case: stepIndex 0 (the first real step).
    /// Confirm that step 0 produces the correct format with no off-by-one surprises.
    @Test func stepIndexZeroEdgeCase() {
        let result = SystemCookStepTimerNotifier.identifier(recipeID: 123, stepIndex: 0)
        #expect(result == "dod.cookMode.stepTimerDone.123.0")
    }

    /// Boundary: recipeID 0 (zero recipe ID, if valid in the domain).
    /// Ensure the identifier format holds even with ID 0.
    @Test func recipeIDZeroEdgeCase() {
        let result = SystemCookStepTimerNotifier.identifier(recipeID: 0, stepIndex: 5)
        #expect(result == "dod.cookMode.stepTimerDone.0.5")
    }

    /// Large numeric values: ensure no overflow or formatting surprises with large IDs.
    @Test func largeNumericValues() {
        let result = SystemCookStepTimerNotifier.identifier(recipeID: 999999, stepIndex: 50)
        #expect(result == "dod.cookMode.stepTimerDone.999999.50")
    }
}
