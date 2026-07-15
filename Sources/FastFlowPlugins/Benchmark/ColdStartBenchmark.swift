import Foundation

/// Timing result for a cold or warm ASR cycle.
public struct ColdStartBenchmarkResult: Sendable, Codable, Equatable {
    public var engineID: String
    public var engineName: String
    public var mode: String
    public var loadMilliseconds: Double
    public var transcribeMilliseconds: Double
    public var unloadMilliseconds: Double
    public var totalMilliseconds: Double
    public var transcriptPreview: String
    public var sampleCount: Int
    public var notes: String

    public init(
        engineID: String,
        engineName: String,
        mode: String,
        loadMilliseconds: Double,
        transcribeMilliseconds: Double,
        unloadMilliseconds: Double,
        totalMilliseconds: Double,
        transcriptPreview: String,
        sampleCount: Int,
        notes: String
    ) {
        self.engineID = engineID
        self.engineName = engineName
        self.mode = mode
        self.loadMilliseconds = loadMilliseconds
        self.transcribeMilliseconds = transcribeMilliseconds
        self.unloadMilliseconds = unloadMilliseconds
        self.totalMilliseconds = totalMilliseconds
        self.transcriptPreview = transcriptPreview
        self.sampleCount = sampleCount
        self.notes = notes
    }

    public var markdownRow: String {
        let preview = String(transcriptPreview.replacingOccurrences(of: "|", with: "/").prefix(40))
        return "| \(engineID) | \(mode) | \(Self.fmt(loadMilliseconds)) | \(Self.fmt(transcribeMilliseconds)) | \(Self.fmt(unloadMilliseconds)) | \(Self.fmt(totalMilliseconds)) | \(preview) |"
    }

    private static func fmt(_ ms: Double) -> String {
        String(format: "%.1f", ms)
    }
}

/// Acceptance targets for post-idle cold start (see docs/BENCHMARKS.md).
public enum ColdStartAcceptance {
    /// Time from idle-unload to `activate()` completing (model ready).
    public static let timeToReadyAfterIdleMS: Double = 1_500
    /// Time from ready + audio available to final transcript (batch path).
    public static let timeToFinalTranscriptMS: Double = 1_000
    /// Combined load + transcribe for a ~1s utterance after idle unload.
    public static let endToEndAfterIdleMS: Double = 2_500
}

/// Runs load → transcribe → unload and prints timings.
public enum ASRColdStartBenchmark {
    public static func syntheticSpeech(seconds: Double = 1.0, sampleRate: Double = 16_000) -> [Float] {
        let n = Int(seconds * sampleRate)
        var samples = [Float](repeating: 0, count: n)
        let freq: Float = 220
        for i in 0..<n {
            let t = Float(i) / Float(sampleRate)
            samples[i] = 0.2 * sin(2 * Float.pi * freq * t)
        }
        return samples
    }

    /// Cold: deactivate first, then activate → transcribe → deactivate.
    /// Warm: assume already loaded (or activate without prior unload).
    public static func run(
        engine: any ASREngine,
        mode: String = "cold",
        samples: [Float]? = nil,
        unload: Bool = true,
        enforcer: PluginCapabilityEnforcer = PluginCapabilityEnforcer(),
        modelsCached: Bool = true
    ) async throws -> ColdStartBenchmarkResult {
        let pcm = samples ?? syntheticSpeech()
        var notes: [String] = []

        if mode == "cold" {
            await engine.deactivate()
        }

        try enforcer.assertCanActivate(engine.manifest, modelsCached: modelsCached)

        let loadStart = Date()
        try await engine.activate()
        let loadMS = Date().timeIntervalSince(loadStart) * 1000

        let txStart = Date()
        let text = try await engine.transcribe(pcm)
        let txMS = Date().timeIntervalSince(txStart) * 1000

        var unloadMS: Double = 0
        if unload {
            let u0 = Date()
            await engine.deactivate()
            unloadMS = Date().timeIntervalSince(u0) * 1000
        }

        if engine.manifest.id == StubASREngine.manifestID {
            notes.append("stub engine — replace with Parakeet for production numbers")
        }
        #if !FASTFLOW_USE_FLUIDAUDIO
        notes.append("built without FluidAudio")
        #endif

        return ColdStartBenchmarkResult(
            engineID: engine.manifest.id,
            engineName: engine.name,
            mode: mode,
            loadMilliseconds: loadMS,
            transcribeMilliseconds: txMS,
            unloadMilliseconds: unloadMS,
            totalMilliseconds: loadMS + txMS + unloadMS,
            transcriptPreview: text,
            sampleCount: pcm.count,
            notes: notes.joined(separator: "; ")
        )
    }

    public static func runDefaultSuite() async throws -> [ColdStartBenchmarkResult] {
        PluginBootstrap.registerBuiltins()
        var results: [ColdStartBenchmarkResult] = []

        let stub = StubASREngine()
        results.append(try await run(engine: stub, mode: "cold", modelsCached: true))
        try await stub.activate()
        results.append(try await run(engine: stub, mode: "warm", unload: false, modelsCached: true))
        await stub.deactivate()

        #if FASTFLOW_USE_FLUIDAUDIO
        let parakeet = ParakeetTDTEngine()
        do {
            // First download may need network escape or NetworkPluginHost.
            let enforcer = PluginCapabilityEnforcer(
                allowInProcessNetworkEscape: PluginCapabilityEnforcer.escapeFromEnvironment()
            )
            results.append(try await run(
                engine: parakeet,
                mode: "cold",
                modelsCached: enforcer.allowInProcessNetworkEscape,
                enforcer: enforcer
            ))
        } catch {
            results.append(ColdStartBenchmarkResult(
                engineID: ParakeetTDTEngine.manifestID,
                engineName: "Parakeet TDT v3",
                mode: "cold",
                loadMilliseconds: -1,
                transcribeMilliseconds: -1,
                unloadMilliseconds: -1,
                totalMilliseconds: -1,
                transcriptPreview: "",
                sampleCount: 0,
                notes: "SKIPPED: \(error.localizedDescription). Run with models cached, or FASTFLOW_ALLOW_INPROCESS_NETWORK=1 for first download / NetworkPluginHost."
            ))
        }
        #else
        results.append(ColdStartBenchmarkResult(
            engineID: ParakeetTDTEngine.manifestID,
            engineName: "Parakeet TDT v3",
            mode: "cold",
            loadMilliseconds: -1,
            transcribeMilliseconds: -1,
            unloadMilliseconds: -1,
            totalMilliseconds: -1,
            transcriptPreview: "",
            sampleCount: 0,
            notes: "SKIPPED: build with FluidAudio (default Package.swift). TODO: fill after first successful cold start."
        ))
        #endif

        return results
    }

    public static func printReport(_ results: [ColdStartBenchmarkResult]) {
        print("FastFlow ASR cold-start benchmark")
        print("Acceptance: ready≤\(ColdStartAcceptance.timeToReadyAfterIdleMS)ms, final≤\(ColdStartAcceptance.timeToFinalTranscriptMS)ms, e2e≤\(ColdStartAcceptance.endToEndAfterIdleMS)ms")
        print("| engine | mode | load_ms | transcribe_ms | unload_ms | total_ms | preview |")
        print("|---|---|---|---|---|---|---|")
        for r in results {
            print(r.markdownRow)
            if !r.notes.isEmpty { print("  notes: \(r.notes)") }
            if r.loadMilliseconds >= 0 {
                let readyOK = r.loadMilliseconds <= ColdStartAcceptance.timeToReadyAfterIdleMS
                let txOK = r.transcribeMilliseconds <= ColdStartAcceptance.timeToFinalTranscriptMS
                let e2e = r.loadMilliseconds + r.transcribeMilliseconds
                let e2eOK = e2e <= ColdStartAcceptance.endToEndAfterIdleMS
                print("  gate: ready=\(readyOK ? "PASS" : "FAIL") tx=\(txOK ? "PASS" : "FAIL") e2e=\(e2eOK ? "PASS" : "FAIL")")
            }
        }
    }
}
