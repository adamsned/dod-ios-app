import Testing

@testable import DODSupport

/// L1 coverage for ``GuidedCookout/cookingSteps`` — the curated, in-order
/// step-by-step cook-along that drives the `.cook` stage's Cook-Mode-style
/// ``StepWalkthroughView``. Pins that the First Cookout carries the real,
/// curated recipe steps and that other cookouts (dump cakes) fall back to an
/// empty walkthrough (the single coaching card).
@Suite("GuidedCookout.cookingSteps")
struct GuidedCookoutCookingStepsTests {

    private var cookingSteps: [String] { GuidedCookout.firstCookout.cookingSteps }

    @Test func firstCookoutHasTheFullCuratedCookAlong() {
        #expect(cookingSteps.count == 21)
        #expect(cookingSteps.first?.hasPrefix("Brown the ground beef") == true)
        // The last step is the garnish / serve line.
        #expect(cookingSteps.last == "Garnish with fresh basil or parsley. Serve and enjoy.")
    }

    @Test func everyStepIsNonEmpty() {
        for step in cookingSteps {
            #expect(step.isEmpty == false)
        }
    }

    /// No em dashes in user-facing copy (house style).
    @Test func noStepContainsAnEmDash() {
        for step in cookingSteps {
            #expect(step.contains("—") == false)
        }
    }

    /// Dump cakes take the fallback path: an empty walkthrough → the `.cook`
    /// stage shows its single coaching card instead.
    @Test func dumpCakeHasNoWalkthroughSteps() {
        let cake = DumpCake(
            id: 16370,
            slug: "lemon-blueberry-dump-cake",
            title: "Lemon Blueberry Dump Cake"
        )
        #expect(GuidedCookout.dumpCake(cake).cookingSteps.isEmpty)
    }
}
