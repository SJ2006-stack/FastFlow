import Foundation
import FastFlowPlugins

/// Orchestrates hold-to-talk → capture → ASREngine → verified insert (or confirmation).
@MainActor
final class DictationSession {
    private let audio = AudioCapture()
    private let privacy = PrivacyIndicator()
    private let idle = IdleUnloadScheduler()
    private let insertion = InsertionRouter()
    private var engine: any ASREngine
    private var biasStore: any BiasListStore
    private var levelTimer: Timer?
    private var isListening = false
    private var isBusy = false
    /// Active utterance context (trigger + Option A focus snapshot).
    private var activeContext: DictationSessionContext?

    var onStateChange: ((MenuBarIconState) -> Void)?
    var onEngineChange: ((String) -> Void)?

    init(engine: any ASREngine, biasStore: any BiasListStore = InMemoryBiasListStore()) {
        self.engine = engine
        self.biasStore = biasStore
        idle.idleTimeoutSeconds = 60
        idle.onIdle = { [weak self] in
            await self?.unloadIfIdle()
        }
    }

    var engineName: String { engine.name }
    var engineID: String { engine.manifest.id }
    var approxMemoryMB: Int { engine.approxActiveMemoryMB }

    func replaceEngine(_ newEngine: any ASREngine) async {
        await engine.deactivate()
        engine = newEngine
        onEngineChange?(engine.name)
    }

    func warmUp() async {
        onStateChange?(.loading)
        do {
            if engine.requiresNetwork {
                NSLog("FastFlow: engine \(engine.manifest.id) declares requiresNetwork (advisory)")
            }
            let t0 = Date()
            try await engine.activate()
            let loadMS = Date().timeIntervalSince(t0) * 1000
            NSLog("FastFlow: warm-up load_ms=%.1f (acceptance ready≤%.0f)", loadMS, ColdStartAcceptance.timeToReadyAfterIdleMS)
            try await biasStore.activate()
            let words = try await biasStore.allWords()
            await engine.applyBiasList(words)
            idle.ping()
            onStateChange?(.idle)
        } catch {
            onStateChange?(.error)
            NSLog("FastFlow warm-up failed: \(error.localizedDescription)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.onStateChange?(.idle)
            }
        }
    }

    /// Hotkey path — capture focus immediately (Option A).
    func beginListening(trigger: TriggerSource = .hotkey) {
        guard !isBusy, !isListening else { return }
        guard PermissionGate.microphoneAuthorized() else {
            onStateChange?(.error)
            Task { _ = await PermissionGate.requestMicrophone() }
            return
        }

        // Option A: snapshot focus at trigger before any audio work.
        let snapshot = FocusProbe.captureSnapshot()
        activeContext = DictationSessionContext(
            trigger: trigger,
            initialFocusSnapshot: snapshot
        )

        do {
            try audio.start()
            isListening = true
            privacy.set(.microphone, active: true)
            ChimePlayer.playStart()
            onStateChange?(.listening(level: 0))
            startLevelPulse()
            idle.cancel()
        } catch {
            activeContext = nil
            onStateChange?(.error)
            NSLog("FastFlow audio start failed: \(error.localizedDescription)")
        }
    }

    func endListening() {
        guard isListening else { return }
        isListening = false
        stopLevelPulse()
        ChimePlayer.playStop()
        privacy.set(.microphone, active: false)

        let sessionContext = activeContext
        activeContext = nil

        let samples = audio.stop()
        guard samples.count > Int(0.2 * AudioCapture.targetSampleRate) else {
            onStateChange?(.idle)
            idle.ping()
            return
        }

        isBusy = true
        onStateChange?(.transcribing)
        Task {
            defer {
                isBusy = false
                idle.ping()
            }
            do {
                var loadMS: Double = 0
                if !engine.isActive {
                    let t0 = Date()
                    try await engine.activate()
                    loadMS = Date().timeIntervalSince(t0) * 1000
                    NSLog("FastFlow: cold activate after idle load_ms=%.1f", loadMS)
                }
                let t1 = Date()
                let text = try await engine.transcribe(samples)
                let txMS = Date().timeIntervalSince(t1) * 1000
                NSLog(
                    "FastFlow: transcribe_ms=%.1f e2e_ms=%.1f (gates ready≤%.0f tx≤%.0f e2e≤%.0f)",
                    txMS,
                    loadMS + txMS,
                    ColdStartAcceptance.timeToReadyAfterIdleMS,
                    ColdStartAcceptance.timeToFinalTranscriptMS,
                    ColdStartAcceptance.endToEndAfterIdleMS
                )
                _ = samples
                if !text.isEmpty {
                    let ctx = sessionContext ?? DictationSessionContext(
                        trigger: .hotkey,
                        initialFocusSnapshot: FocusProbe.captureSnapshot()
                    )
                    // Option B + never-silently-guess lives in InsertionRouter.
                    _ = insertion.deliver(text: text, session: ctx)
                }
                onStateChange?(.idle)
            } catch {
                NSLog("FastFlow transcribe failed: \(error.localizedDescription)")
                onStateChange?(.error)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                onStateChange?(.idle)
            }
        }
    }

    private func unloadIfIdle() async {
        guard !isListening, !isBusy else { return }
        await engine.deactivate()
        NSLog("FastFlow: ASR unloaded after idle timeout (\(engine.approxActiveMemoryMB) MB budget)")
    }

    private func startLevelPulse() {
        stopLevelPulse()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.isListening else { return }
                self.onStateChange?(.listening(level: self.audio.currentLevel))
            }
        }
    }

    private func stopLevelPulse() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    func shutdown() async {
        idle.cancel()
        stopLevelPulse()
        audio.shutdown()
        await engine.deactivate()
        await biasStore.deactivate()
    }
}
