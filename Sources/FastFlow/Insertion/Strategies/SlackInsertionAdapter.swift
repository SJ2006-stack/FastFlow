import AppKit
import ApplicationServices
import Foundation
import FastFlowPlugins

/// Slack Electron AX trees are inconsistent — do not trust focused-element AX alone.
/// Still obeys core resolver: never auto-insert when ambiguous / wake-word unknown.
@MainActor
final class SlackInsertionAdapter: TextInsertionStrategy {
    static let slackBundleID = "com.tinyspeck.slackmacgap"

    let name = "Slack (clipboard-paste fallback)"
    let supportedTargets = TargetMatcher.bundleID(Self.slackBundleID)

    func resolveTarget(for session: DictationSessionContext) -> InsertionTarget {
        let current = FocusProbe.captureSnapshot()
        let front = NSWorkspace.shared.frontmostApplication
        let slackFrontmost = front?.bundleIdentifier == Self.slackBundleID

        // Slack-specific: require Slack frontmost; treat compose heuristics loosely.
        guard slackFrontmost else {
            return .ambiguous(reason: "Slack adapter matched but Slack is not frontmost.")
        }

        let verdict = InsertionResolver.resolve(
            trigger: session.trigger,
            initial: session.initialFocusSnapshot,
            current: current ?? FocusSnapshot(
                pid: Int32(front?.processIdentifier ?? 0),
                bundleID: Self.slackBundleID,
                role: "AXTextArea",
                subrole: nil,
                title: "Slack compose (heuristic)",
                isTextInput: session.trigger == .hotkey,
                identityToken: "slack-frontmost",
                capturedAt: .now
            )
        )

        switch verdict {
        case .verified:
            // Electron: prefer clipboard path; AX element may be a stub.
            if let element = FocusProbe.focusedElement() {
                return .verified(element)
            }
            return .verified(AXUIElementCreateSystemWide())
        case .ambiguous(let reason):
            return .ambiguous(reason: reason)
        case .unavailable(let reason):
            // Hotkey + Slack frontmost: still allow verified via clipboard if user was engaged.
            if session.trigger == .hotkey {
                return .verified(AXUIElementCreateSystemWide())
            }
            return .unavailable(reason: reason)
        }
    }

    func insert(text: String, into target: InsertionTarget) throws {
        guard case .verified = target else { throw InsertionError.notVerified }
        guard !text.isEmpty else { throw InsertionError.emptyText }
        // save clipboard → set → Cmd+V → restore
        guard PasteService.paste(text) else { throw InsertionError.clipboardFailed }
    }
}
