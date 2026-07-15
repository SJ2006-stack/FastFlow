import ApplicationServices
import Foundation
import FastFlowPlugins

/// Default path for native / well-behaved apps: direct AX value write.
@MainActor
final class AXInsertionStrategy: TextInsertionStrategy {
    let name = "Accessibility API (default)"
    let supportedTargets = TargetMatcher(isDefaultAX: true)

    func resolveTarget(for session: DictationSessionContext) -> InsertionTarget {
        let current = FocusProbe.captureSnapshot()
        let verdict = InsertionResolver.resolve(
            trigger: session.trigger,
            initial: session.initialFocusSnapshot,
            current: current
        )
        switch verdict {
        case .verified:
            guard let element = FocusProbe.focusedElement() else {
                return .unavailable(reason: "Verified verdict but focused element disappeared.")
            }
            return .verified(element)
        case .ambiguous(let reason):
            return .ambiguous(reason: reason)
        case .unavailable(let reason):
            return .unavailable(reason: reason)
        }
    }

    func insert(text: String, into target: InsertionTarget) throws {
        guard case .verified(let element) = target else { throw InsertionError.notVerified }
        guard !text.isEmpty else { throw InsertionError.emptyText }

        // Prefer replacing/appending via AXValue when settable.
        var settable: DarwinBoolean = false
        let settableStatus = AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &settable
        )
        if settableStatus == .success, settable.boolValue {
            var existing: AnyObject?
            _ = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &existing)
            let prior = (existing as? String) ?? ""
            let combined = prior.isEmpty ? text : prior + text
            let err = AXUIElementSetAttributeValue(
                element,
                kAXValueAttribute as CFString,
                combined as CFTypeRef
            )
            if err == .success { return }
        }

        // Selected-text replace
        let selectedErr = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        if selectedErr == .success { return }

        throw InsertionError.axWriteFailed
    }
}
