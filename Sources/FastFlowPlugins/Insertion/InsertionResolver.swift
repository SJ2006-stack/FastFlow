import Foundation

/// Pure core resolution — not per-strategy.
/// Load-bearing rule: never silently guess; ambiguity → confirmation UI.
public enum InsertionVerdict: Sendable, Equatable {
    case verified
    case ambiguous(reason: String)
    case unavailable(reason: String)
}

public enum InsertionResolver {
    /// Compare initial focus (Option A) to current focus (Option B).
    public static func resolve(
        trigger: TriggerSource,
        initial: FocusSnapshot?,
        current: FocusSnapshot?
    ) -> InsertionVerdict {
        // Wake word into unknown / non-text target → always ambiguous.
        if trigger == .wakeWord {
            if initial == nil || initial?.isTextInput != true {
                return .ambiguous(
                    reason: "Wake-word dictation without a known text field at trigger — will not insert blindly."
                )
            }
        }

        guard let current else {
            return .unavailable(reason: "No focused UI element at insertion time.")
        }

        guard current.isTextInput else {
            return .unavailable(reason: "Focused element is not a text-input role.")
        }

        guard let initial else {
            if trigger == .hotkey {
                return .verified
            }
            return .ambiguous(reason: "No initial focus snapshot; wake-word path requires confirmation.")
        }

        if initial.isSameElement(as: current), current.isTextInput {
            return .verified
        }

        if initial.isSameApp(as: current), current.isTextInput, trigger == .hotkey {
            return .verified
        }

        if !initial.isSameApp(as: current) {
            return .ambiguous(
                reason: "Focus moved to a different app (\(initial.bundleID ?? "?") → \(current.bundleID ?? "?"))."
            )
        }

        return .ambiguous(
            reason: "Focus moved within the app during wake-word dictation."
        )
    }
}
