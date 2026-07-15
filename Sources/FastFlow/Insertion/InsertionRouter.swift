import AppKit
import Foundation
import FastFlowPlugins

/// Priority when multiple strategies match:
/// 1. App-specific adapter
/// 2. Default AX insertion
/// 3. Clipboard-paste fallback
/// 4. Ambiguous → floating confirmation (never silent guess)
@MainActor
final class InsertionRouter {
    private let strategies: [any TextInsertionStrategy]
    private let confirmation: InsertionConfirmationPresenter

    init(
        strategies: [any TextInsertionStrategy]? = nil,
        confirmation: InsertionConfirmationPresenter = InsertionConfirmationPresenter()
    ) {
        self.strategies = strategies ?? [
            SlackInsertionAdapter(),
            AXInsertionStrategy(),
            ClipboardPasteStrategy(),
        ]
        self.confirmation = confirmation
    }

    /// Resolve + insert, or show confirmation. Never silently guesses.
    @discardableResult
    func deliver(text: String, session: DictationSessionContext) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let strategy = pickStrategy(for: session)
        let target = strategy.resolveTarget(for: session)

        switch target {
        case .verified:
            do {
                try strategy.insert(text: trimmed, into: target)
                NSLog("FastFlow insert OK via \(strategy.name) (trigger=\(session.trigger.rawValue))")
                return true
            } catch {
                NSLog("FastFlow insert failed (\(strategy.name)): \(error.localizedDescription)")
                confirmation.present(
                    transcript: trimmed,
                    reason: "Insert failed: \(error.localizedDescription). Copy or place manually."
                )
                return false
            }

        case .ambiguous(let reason), .unavailable(let reason):
            NSLog("FastFlow insert withheld (\(session.trigger.rawValue)): \(reason)")
            confirmation.present(transcript: trimmed, reason: reason)
            return false
        }
    }

    private func pickStrategy(for session: DictationSessionContext) -> any TextInsertionStrategy {
        let current = FocusProbe.captureSnapshot()
        let bundleID = current?.bundleID
            ?? session.initialFocusSnapshot?.bundleID
            ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let role = current?.role

        // 1. App-specific (non-default, non-universal)
        if let specific = strategies.first(where: {
            !$0.supportedTargets.isDefaultAX
                && !$0.supportedTargets.isUniversalFallback
                && $0.supportedTargets.matches(bundleID: bundleID, role: role)
        }) {
            return specific
        }

        // 2. Default AX
        if let ax = strategies.first(where: { $0.supportedTargets.isDefaultAX }) {
            // Prefer AX when we have a real text field; else fall through to clipboard.
            if current?.isTextInput == true || session.initialFocusSnapshot?.isTextInput == true {
                return ax
            }
        }

        // 3. Clipboard universal
        if let clip = strategies.first(where: { $0.supportedTargets.isUniversalFallback }) {
            return clip
        }

        return strategies[0]
    }
}
