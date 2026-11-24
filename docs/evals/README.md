# Evaluations Framework

## Purpose

The evals complement the deterministic unit tests on `DutchOvenHeatCoach` and `IngredientAisleClassifier`. They check the non-deterministic AI paths for safety framing, constrained output, structural fidelity and groundedness.

## Layout

Everything is under `Packages/DODIntelligence/Tests/DODIntelligenceTests/Evals/`:
* `EvalTypes.swift` (`EvalCase`, `EvalOutcome`, `EvalReport`, `runEval`)
* `EvalGraders.swift` (`nonEmpty`, `forbids`, `requiresAny`, `integers`, `numbersGrounded`)
* `AisleClassifierEval.swift`
* `HeatCoachGroundednessEval.swift`
* `IntelligenceServiceEval.swift`

## Running

`cd Packages/DODIntelligence && swift test --filter Eval`. Per-PR runs use `FakeIntelligenceService`, because the live model is unavailable on CI and in the simulator.

## Adding an eval

Add an `EvalCase` corpus and a `grade` function that returns `[String]` failures. Wrap it with `runEval`, and assert `report.meets(threshold:)` with `report.failureSummary` as the comment.

## Evaluations framework adapter (iOS 27)

The adapter must be guarded with `#if canImport(Evaluations)` and kept out of the macOS slice. It feeds the same `EvalCase` inputs and `grade` closures to the framework, so the graders are shared. Mark the live-model run as opt-in and device-only.

## Coverage still to wire up

Each needs a corpus and a grader built from the existing graders:
* doneness-from-photo, using `gradeDonenessAnswer` plus `imageData`
* OCR-import structural fidelity
* fridge-finder relevance
* Heat-Coach tool-calling

## Gate

No AI feature in this cohort exits development until it has an eval here that passes its threshold.