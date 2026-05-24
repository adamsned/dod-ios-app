import DODAnalytics
import DODDomain
import Foundation
import Observation

#if canImport(UIKit)
import UIKit
#endif

/// Drives Cook Mode (US-7) step navigation and the screen-stay-awake toggle.
/// Kept separate from ``CookModeView`` so the navigation rules, the
/// "finished" terminal state, and the symmetric `isIdleTimerDisabled`
/// behaviour can be unit-tested without booting SwiftUI.
///
/// Telemetry note: this VM does **not** fire `cookModeStarted` itself —
/// the CTA tap site in ``RecipeDetailView`` owns that send so the event
/// matches AC-7.7 "first time Cook Mode is entered for a given recipe
/// during a session" without depending on VM re-instantiation order.
///
/// Spec trace:
/// - AC-7.3 — sets the idle timer on entry, restores prior value on exit.
/// - AC-7.4 — `goNext` clamps at the last step, `goBack` clamps at zero,
///   `isFinished` flips true only after the user advances past the last step.
/// - AC-7.5 — ingredient check state is seeded in and surfaced back out so
///   it round-trips with recipe detail.
/// - AC-7.6 — `endCookMode` restores the idle timer regardless of where the
///   user is in the flow.
@Observable
@MainActor
public final class CookModeViewModel {

    public let recipe: Recipe
    public private(set) var currentStepIndex: Int = 0
    public private(set) var isFinished: Bool = false
    public var checkedIngredientIDs: Set<UUID>

    private let idleTimer: any IdleTimerController
    private var priorIdleTimerDisabled: Bool = false
    private var didBegin: Bool = false

    public init(
        recipe: Recipe,
        initialCheckedIngredients: Set<UUID>,
        idleTimer: any IdleTimerController = SystemIdleTimerController()
    ) {
        self.recipe = recipe
        self.checkedIngredientIDs = initialCheckedIngredients
        self.idleTimer = idleTimer
    }

    /// Total number of steps, derived from the recipe. Zero if the recipe
    /// has no instructions parsed (Cook Mode shouldn't even be presented in
    /// that case — guarded by the entry CTA).
    public var stepCount: Int {
        recipe.instructions.count
    }

    /// The instruction currently being shown to the user.
    public var currentStep: RecipeInstruction? {
        guard currentStepIndex >= 0, currentStepIndex < recipe.instructions.count else {
            return nil
        }
        return recipe.instructions[currentStepIndex]
    }

    /// True when we're on the last step (so the bottom-bar CTA reads
    /// "Done cooking" instead of "Next").
    public var isOnLastStep: Bool {
        currentStepIndex == max(0, recipe.instructions.count - 1)
    }

    /// True after `beginCookMode` and before `endCookMode` — exposed for tests.
    public var isIdleTimerDisabled: Bool {
        idleTimer.isDisabled
    }

    // MARK: - Lifecycle

    /// Called on view appear: captures the prior idle-timer value and sets
    /// it to `true`. Safe to call repeatedly — only the first call has effect.
    public func beginCookMode() {
        guard !didBegin else { return }
        didBegin = true
        priorIdleTimerDisabled = idleTimer.isDisabled
        idleTimer.isDisabled = true
    }

    /// Called on view disappear: restores the previous idle-timer value.
    /// Symmetric with `beginCookMode` (AC-7.3, AC-7.6).
    public func endCookMode() {
        guard didBegin else { return }
        idleTimer.isDisabled = priorIdleTimerDisabled
        didBegin = false
    }

    // MARK: - Navigation

    public func goNext() {
        if currentStepIndex < recipe.instructions.count - 1 {
            currentStepIndex += 1
        } else {
            isFinished = true
        }
    }

    public func goBack() {
        if isFinished {
            isFinished = false
            return
        }
        if currentStepIndex > 0 {
            currentStepIndex -= 1
        }
    }

    // MARK: - Ingredient state

    public func toggleIngredient(_ id: UUID) {
        if checkedIngredientIDs.contains(id) {
            checkedIngredientIDs.remove(id)
        } else {
            checkedIngredientIDs.insert(id)
        }
    }
}

// MARK: - Idle timer abstraction

/// Lets the view model drive `UIApplication.isIdleTimerDisabled` in
/// production while letting tests stub the property with a plain class.
/// Marker-only protocol — the actual production conformance lives in
/// ``SystemIdleTimerController``.
@MainActor
public protocol IdleTimerController: AnyObject {
    var isDisabled: Bool { get set }
}

/// Production conformance — backed by `UIApplication.shared.isIdleTimerDisabled`.
/// On non-UIKit hosts (e.g. swift test on macOS), reads/writes a local
/// boolean so the type still satisfies the protocol.
@MainActor
public final class SystemIdleTimerController: IdleTimerController {

    public init() {}

    public var isDisabled: Bool {
        get {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled
            #else
            localValue
            #endif
        }
        set {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = newValue
            #else
            localValue = newValue
            #endif
        }
    }

    #if !canImport(UIKit)
    private var localValue: Bool = false
    #endif
}
