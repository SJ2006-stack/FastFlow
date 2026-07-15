import Foundation

/// How dictation was started. Affects insertion confidence.
public enum TriggerSource: String, Sendable, Equatable, Codable {
    /// Hands at keyboard — high focus confidence.
    case hotkey
    /// Hands-free — lower focus confidence; target may be stale.
    case wakeWord
}

/// Focus identity captured at a point in time (trigger or insert).
public struct FocusSnapshot: Sendable, Equatable, Codable {
    public let pid: Int32
    public let bundleID: String?
    public let role: String?
    public let subrole: String?
    public let title: String?
    public let isTextInput: Bool
    /// Stable-enough token for same-element checks within a session.
    public let identityToken: String
    public let capturedAt: Date

    public init(
        pid: Int32,
        bundleID: String?,
        role: String?,
        subrole: String?,
        title: String?,
        isTextInput: Bool,
        identityToken: String,
        capturedAt: Date = .now
    ) {
        self.pid = pid
        self.bundleID = bundleID
        self.role = role
        self.subrole = subrole
        self.title = title
        self.isTextInput = isTextInput
        self.identityToken = identityToken
        self.capturedAt = capturedAt
    }

    public static func == (lhs: FocusSnapshot, rhs: FocusSnapshot) -> Bool {
        lhs.pid == rhs.pid
            && lhs.bundleID == rhs.bundleID
            && lhs.identityToken == rhs.identityToken
            && lhs.isTextInput == rhs.isTextInput
    }

    public func isSameElement(as other: FocusSnapshot) -> Bool {
        pid == other.pid
            && bundleID == other.bundleID
            && identityToken == other.identityToken
    }

    public func isSameApp(as other: FocusSnapshot) -> Bool {
        if let a = bundleID, let b = other.bundleID { return a == b }
        return pid == other.pid
    }
}

/// Session context carried from trigger → transcription → insertion.
public struct DictationSessionContext: Sendable {
    public let trigger: TriggerSource
    public let triggeredAt: Date
    public let initialFocusSnapshot: FocusSnapshot?

    public init(
        trigger: TriggerSource,
        triggeredAt: Date = .now,
        initialFocusSnapshot: FocusSnapshot?
    ) {
        self.trigger = trigger
        self.triggeredAt = triggeredAt
        self.initialFocusSnapshot = initialFocusSnapshot
    }
}
