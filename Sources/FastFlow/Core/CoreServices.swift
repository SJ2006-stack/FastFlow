import Foundation

/// Owns idle unload + privacy indicator + raw media retention policy.
/// These stay in CORE — never pluggable.
@MainActor
final class IdleUnloadScheduler {
    private var task: Task<Void, Never>?
    var idleTimeoutSeconds: TimeInterval = 60
    var onIdle: (() async -> Void)?

    func ping() {
        task?.cancel()
        let timeout = idleTimeoutSeconds
        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.onIdle?()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

/// Mic / screen capture privacy cue (menu bar / future HUD).
@MainActor
final class PrivacyIndicator {
    enum CaptureKind: String {
        case microphone
        case screen
    }

    private(set) var activeKinds: Set<CaptureKind> = []

    func set(_ kind: CaptureKind, active: Bool) {
        if active {
            activeKinds.insert(kind)
        } else {
            activeKinds.remove(kind)
        }
    }

    var isCapturing: Bool { !activeKinds.isEmpty }
}

/// Policy for how long raw PCM / pixels may linger in RAM.
///
/// These are **software conventions**, not OS enforcement against an in-process
/// plug-in. See `docs/PRIVACY.md`.
enum RawMediaRetentionPolicy {
    /// Utterance buffer only — discarded after paste / cancel (core path).
    static let keepUtteranceOnly = true
    /// Never write raw audio/pixels to disk in Phase 1 (core path).
    static let allowDiskPersistence = false
    /// Screen frames must be discarded immediately after parse (Phase 3 core path).
    /// In-process parsers can still copy pixels — XPC parse-only is the real fix.
    static let discardFramesAfterParse = true
}
