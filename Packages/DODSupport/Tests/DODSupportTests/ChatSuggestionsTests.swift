import Foundation
import Testing

@testable import DODSupport

@Suite("Chat suggestions (DUT-2893)")
struct ChatSuggestionsTests {

    @Test func campfireChickenWithButtermilk() {
        let chips = ChatSuggestions.forRecipe(
            title: "Buttermilk Fried Chicken",
            ingredients: ["2 lb chicken thighs", "2 cups buttermilk", "1 cup flour"],
            steps: ["Light 24 coals.", "Fry the chicken."],
            servings: 4
        )
        #expect(
            chips == [
                "What can I use instead of buttermilk?",
                "How many coals do I need on top and bottom?",
                "How do I know when the chicken is done?",
                "How do I double this recipe?",
            ]
        )
    }

    @Test func ovenDessertForACrowdSuggestsCampfireAndHalving() {
        let chips = ChatSuggestions.forRecipe(
            title: "Peach Cobbler",
            ingredients: ["2 cans peaches", "1 box cake mix", "1 stick butter"],
            steps: ["Preheat the oven to 350°F.", "Layer.", "Bake 45 minutes."],
            servings: 12
        )
        #expect(chips.contains("Can I make this over a campfire with coals?"))
        #expect(chips.contains("How do I make half of this?"))
        #expect(chips.contains("What can I use instead of butter?"))
        #expect(chips.contains("Can I make this ahead?"))  // cobbler
        #expect(!chips.contains { $0.contains("done?") })  // no meat
    }

    @Test func respectsLimitAndHasNoDuplicatesOrEmDashes() {
        let chips = ChatSuggestions.forRecipe(
            title: "Beef Stew",
            ingredients: ["2 lb beef", "1 cup red wine"],
            steps: Array(repeating: "Stir over the coals.", count: 8),
            servings: 6,
            limit: 3
        )
        #expect(chips.count == 3)
        #expect(Set(chips).count == chips.count)
        #expect(!chips.joined().contains("\u{2014}"))
    }

    @Test func plainRecipeStillGetsUsefulChips() {
        let chips = ChatSuggestions.forRecipe(
            title: "Rice",
            ingredients: ["1 cup rice"],
            steps: ["Cook."],
            servings: nil
        )
        #expect(chips == ["How do I double this recipe?", "How do I store and reheat leftovers?"])
    }

    @Test func eggsAreSwappableButEggplantIsNot() {
        let eggs = ChatSuggestions.forRecipe(title: "", ingredients: ["2 large eggs"], steps: [], servings: nil)
        #expect(eggs.first == "What can I use instead of eggs?")
        let eggplant = ChatSuggestions.forRecipe(title: "", ingredients: ["1 eggplant"], steps: [], servings: nil)
        #expect(!eggplant.contains { $0.contains("eggs") })
        let pb = ChatSuggestions.forRecipe(title: "", ingredients: ["1/2 cup peanut butter"], steps: [], servings: nil)
        #expect(pb.first == "What can I use instead of peanut butter?")
    }

    @Test func generalRotatesDailyButIsStableWithinADay() {
        let today = ChatSuggestions.general(dayKey: "2026-11-18")
        #expect(today.count == 4)
        #expect(today == ChatSuggestions.general(dayKey: "2026-11-18"))
        #expect(Set(today).isSubset(of: Set(ChatSuggestions.generalPool)))
        let week = (10...16).map { ChatSuggestions.general(dayKey: "2026-11-\($0)") }
        #expect(Set(week.map { $0.joined() }).count > 1)
    }

    @Test func remainingDropsAskedChips() {
        let chips = ["Can I use soap on cast iron?", "How do I store cast iron?"]
        let left = ChatSuggestions.remaining(chips, askedTexts: [" can i use soap on cast iron? "])
        #expect(left == ["How do I store cast iron?"])
    }
}
