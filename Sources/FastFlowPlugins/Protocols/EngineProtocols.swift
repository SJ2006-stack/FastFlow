import Foundation

/// Voice-activity gate used before ASR (optional; dictation starts via hotkey).
public protocol VoiceActivityDetector: FastFlowPlugin {
    func isSpeech(_ frame: AudioFrame) async -> Bool
}

/// Automatic speech recognition engine.
///
/// Replaces / aligns with the plan's `SpeechRecognizer`. Core dictation
/// talks only to this protocol — never to FluidAudio / Whisper directly.
public protocol ASREngine: FastFlowPlugin {
    var supportsStreaming: Bool { get }

    /// Batch transcription of 16 kHz mono Float32 samples.
    func transcribe(_ samples: [Float]) async throws -> String

    /// Optional streaming path. Default engines may ignore and yield one final.
    func stream(_ frames: AsyncStream<AudioFrame>) -> AsyncStream<TranscriptPartial>

    /// Apply bias / boost vocabulary when the engine supports it.
    func applyBiasList(_ words: [BiasedWord]) async
}

public extension ASREngine {
    var supportsStreaming: Bool { manifest.supportsStreaming }

    func stream(_ frames: AsyncStream<AudioFrame>) -> AsyncStream<TranscriptPartial> {
        AsyncStream { continuation in
            Task {
                var buffer: [Float] = []
                for await frame in frames {
                    buffer.append(contentsOf: frame.samples)
                }
                do {
                    let text = try await transcribe(buffer)
                    if !text.isEmpty {
                        continuation.yield(TranscriptPartial(text: text, isFinal: true))
                    }
                } catch {
                    // Engines surface errors via session layer; stream ends quietly.
                }
                continuation.finish()
            }
        }
    }

    func applyBiasList(_ words: [BiasedWord]) async {
        _ = words
    }
}

/// Legacy alias used in early plan drafts — prefer `ASREngine`.
public typealias SpeechRecognizer = ASREngine

/// Screen / field understanding (Phase 3+). Protocols + stubs only for now.
///
/// In-process implementations receive raw `CapturedFrame` pixels. Core retention
/// policy cannot stop a malicious parser from copying them — see docs/PRIVACY.md.
public protocol ScreenContextParser: FastFlowPlugin {
    func parse(_ frame: CapturedFrame) async throws -> ScreenContext
}

/// Persistent correction / boost vocabulary.
public protocol BiasListStore: FastFlowPlugin {
    func allWords() async throws -> [BiasedWord]
    func upsert(_ word: BiasedWord) async throws
    func remove(word: String) async throws
}
