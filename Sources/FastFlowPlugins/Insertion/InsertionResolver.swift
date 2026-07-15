import Foundation

/// Pure core resolution — not per-strategy.
/// Load-bearing rule: never silently guess; ambiguity → confirmation UI.
///
/// Dictation is **hotkey-only** (push-to-talk). Hands are at the keyboard,
/// so same-app field changes are treated as verified.
public enum InsertionVerdict: Sendable, Equatable {
    case verified
    case ambiguous(reason: String)
    case unavailable(reason: String)
}

public enum InsertionResolver {
    /// Compare initial focus (Option A) to current focus (Option B).
    public static func resolve(
        trigger: TriggerSource = .hotkey,
        initial: FocusSnapshot?,
        current: FocusSnapshot?
    ) -> InsertionVerdict {
        _ = trigger // reserved; only `.hotkey` exists today

        guard let current else {
            return .unavailable(reason: "No focused UI element at insertion time.")
        }

        guard current.isTextInput else {
            return .unavailable(reason: "Focused element is not a text-input role.")
        }

        // No snapshot at hotkey press (AX failed) but current is a text field → OK.
        guard let initial else {
            return .verified
        }

        if initial.isSameElement(as: current), current.isTextInput {
            return .verified
        }

        // Same app, different field — user is engaged via hotkey.
        if initial.isSameApp(as: current), current.isTextInput {
            return .verified
        }

        if !initial.isSameApp(as: current) {
            return .ambiguous(
                reason: "Focus moved to a different app (\(initial.bundleID ?? "?") → \(current.bundleID ?? "?"))."
            )
        }

        return .ambiguous(reason: "Could not verify a stable text-input target.")
    }
}
