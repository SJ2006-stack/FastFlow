import ApplicationServices
import Foundation
import FastFlowPlugins

/// Universal clipboard + Cmd+V fallback (heavier-handed).
/// Still only runs after core resolution returns `.verified`.
@MainActor
final class ClipboardPasteStrategy: TextInsertionStrategy {
    let name = "Clipboard paste (universal fallback)"
    let supportedTargets = TargetMatcher(isUniversalFallback: true)

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
                // Hotkey + frontmost text path may still paste without AX element.
                if session.trigger == .hotkey, current?.isTextInput == true {
                    return .verified(AXUIElementCreateSystemWide())
                }
                return .unavailable(reason: "No focused element for clipboard paste.")
            }
            return .verified(element)
        case .ambiguous(let reason):
            return .ambiguous(reason: reason)
        case .unavailable(let reason):
            return .unavailable(reason: reason)
        }
    }

    func insert(text: String, into target: InsertionTarget) throws {
        guard case .verified = target else { throw InsertionError.notVerified }
        guard !text.isEmpty else { throw InsertionError.emptyText }
        guard PasteService.paste(text) else { throw InsertionError.clipboardFailed }
    }
}
