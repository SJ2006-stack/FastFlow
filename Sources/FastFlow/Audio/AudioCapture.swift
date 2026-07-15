import AVFoundation
import Foundation

/// Captures mic audio and resamples to 16 kHz mono Float32.
/// Not @MainActor — AVAudioEngine tap fires on an audio thread.
final class AudioCapture: @unchecked Sendable {
    static let targetSampleRate: Double = 16_000

    private var engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let lock = NSLock()
    private var samples: [Float] = []
    private var _isRecording = false
    private var _level: Float = 0
    private var tapInstalled = false

    var isRecording: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isRecording
    }

    var currentLevel: Float {
        lock.lock(); defer { lock.unlock() }
        return _level
    }

    func start() throws {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        _level = 0
        _isRecording = true
        let alreadyTapped = tapInstalled
        lock.unlock()

        if alreadyTapped {
            if !engine.isRunning {
                try engine.start()
            }
            return
        }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioCaptureError.formatFailed
        }

        let sourceFormat: AVAudioFormat
        if inputFormat.channelCount == 1 {
            sourceFormat = inputFormat
        } else if let mono = AVAudioFormat(
            commonFormat: inputFormat.commonFormat,
            sampleRate: inputFormat.sampleRate,
            channels: 1,
            interleaved: inputFormat.isInterleaved
        ) {
            sourceFormat = mono
        } else {
            sourceFormat = inputFormat
        }

        converter = AVAudioConverter(from: sourceFormat, to: targetFormat)

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.handleTap(buffer: buffer, target: targetFormat)
        }
        lock.lock()
        tapInstalled = true
        lock.unlock()

        try engine.start()
    }

    func stop() -> [Float] {
        lock.lock()
        _isRecording = false
        _level = 0
        let captured = samples
        samples.removeAll(keepingCapacity: true)
        lock.unlock()
        return captured
    }

    func shutdown() {
        _ = stop()
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        engine.reset()
        converter = nil
        engine = AVAudioEngine()
    }

    private func handleTap(buffer: AVAudioPCMBuffer, target: AVAudioFormat) {
        lock.lock()
        let recording = _isRecording
        let converter = self.converter
        lock.unlock()
        guard recording, let converter else { return }

        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }

        var error: NSError?
        var consumed = false
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        _ = status
        guard error == nil, let channel = out.floatChannelData?[0], out.frameLength > 0 else { return }

        let count = Int(out.frameLength)
        let pointer = UnsafeBufferPointer(start: channel, count: count)
        let chunk = Array(pointer)

        var sum: Float = 0
        for s in chunk { sum += s * s }
        let rms = sqrt(sum / Float(max(count, 1)))

        lock.lock()
        if _isRecording {
            samples.append(contentsOf: chunk)
            _level = min(1, rms * 8)
        }
        lock.unlock()
    }
}

enum AudioCaptureError: LocalizedError {
    case formatFailed
    var errorDescription: String? { "Could not create 16 kHz mono audio format." }
}
