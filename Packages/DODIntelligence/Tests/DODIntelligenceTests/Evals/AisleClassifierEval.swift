import DODSupport
import Foundation

struct AisleExpectation: Sendable {
    let line: String
    /// nil = any aisle is acceptable; the case only checks the output is constrained.
    let expected: IngredientAisleClassifier.Aisle?
}

enum AisleClassifierEval {

    static let corpus: [EvalCase<AisleExpectation>] = [
        .init(name: "onion", input: .init(line: "2 cups diced yellow onion", expected: .produce)),
        .init(name: "garlic", input: .init(line: "3 cloves garlic, minced", expected: .produce)),
        .init(name: "chicken", input: .init(line: "1 ½ pounds boneless skinless chicken thighs", expected: .meat)),
        .init(name: "paprika", input: .init(line: "1 tsp smoked paprika", expected: .spices)),
        .init(name: "empty", input: .init(line: "", expected: .other)),
        .init(name: "unicode", input: .init(line: "  ½ cup  CRÈME FRAÎCHE  ", expected: nil)),
        .init(name: "gibberish", input: .init(line: "zzqx 123 !!!", expected: .other)),
    ]

    /// Returns failure strings: output must be a valid Aisle (round-trips its rawValue)
    /// and, when an expectation exists, must equal it.
    static func grade(_ item: AisleExpectation) -> [String] {
        let aisle = IngredientAisleClassifier.classify(item.line)
        var failures: [String] = []
        if IngredientAisleClassifier.Aisle(rawValue: aisle.rawValue) != aisle {
            failures.append("raw value does not round-trip")
        }
        if let expected = item.expected, aisle != expected {
            failures.append("expected \(expected.rawValue), got \(aisle.rawValue)")
        }
        return failures
    }
}
