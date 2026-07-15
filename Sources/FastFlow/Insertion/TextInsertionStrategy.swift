import ApplicationServices
import Foundation
import FastFlowPlugins

/// Result of focus re-verification before insert.
/// Never silently guess — ambiguous/unavailable must surface UI.
enum InsertionTarget {
    /// Focus confirmed stable (or hotkey same-app retarget); safe to auto-insert.
    case verified(AXUIElement)
    /// Focus moved / unclear / unsupported — show confirmation, do not auto-insert.
    case ambiguous(reason: String)
    /// No valid text-input target at all.
    case unavailable(reason: String)
}

/// Matches apps / AX roles a strategy is built for.
struct TargetMatcher: Sendable {
    var bundleIDs: Set<String>
    var roles: Set<String>
    /// If true, this strategy is the universal fallback (clipboard-paste).
    var isUniversalFallback: Bool
    /// If true, this is the default AX path for well-behaved native apps.
    var isDefaultAX: Bool

    init(
        bundleIDs: Set<String> = [],
        roles: Set<String> = [],
        isUniversalFallback: Bool = false,
        isDefaultAX: Bool = false
    ) {
        self.bundleIDs = bundleIDs
        self.roles = roles
        self.isUniversalFallback = isUniversalFallback
        self.isDefaultAX = isDefaultAX
    }

    static func bundleID(_ id: String) -> TargetMatcher {
        TargetMatcher(bundleIDs: [id])
    }

    func matches(bundleID: String?, role: String?) -> Bool {
        if isUniversalFallback || isDefaultAX { return true }
        if let bundleID, !bundleIDs.isEmpty, bundleIDs.contains(bundleID) { return true }
        if let role, !roles.isEmpty, roles.contains(role) { return true }
        return false
    }
}

/// Per-app / per-path text insertion adapter (plugin-registered).
@MainActor
protocol TextInsertionStrategy: AnyObject {
    var name: String { get }
    var supportedTargets: TargetMatcher { get }

    func resolveTarget(for session: DictationSessionContext) -> InsertionTarget
    func insert(text: String, into target: InsertionTarget) throws
}

enum InsertionError: LocalizedError {
    case notVerified
    case axWriteFailed
    case clipboardFailed
    case emptyText

    var errorDescription: String? {
        switch self {
        case .notVerified: return "Refusing to insert into a non-verified target."
        case .axWriteFailed: return "Accessibility set-value failed."
        case .clipboardFailed: return "Clipboard paste failed."
        case .emptyText: return "Nothing to insert."
        }
    }
}
