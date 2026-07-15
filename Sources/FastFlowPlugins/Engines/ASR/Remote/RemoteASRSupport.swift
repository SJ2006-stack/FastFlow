import Foundation

/// Encode 16 kHz mono Float32 PCM as a minimal WAV (PCM 16-bit).
enum WAVEncoder {
    static func encodeMono16kHz(_ samples: [Float]) -> Data {
        let sampleRate: UInt32 = 16_000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        var pcm = Data(capacity: samples.count * 2)
        for s in samples {
            let clipped = max(-1.0, min(1.0, s))
            var i = Int16((clipped * Float(Int16.max)).rounded())
            pcm.append(Data(bytes: &i, count: 2))
        }
        let dataSize = UInt32(pcm.count)
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)

        var header = Data()
        func appendASCII(_ s: String) { header.append(contentsOf: s.utf8) }
        func appendU32(_ v: UInt32) {
            var le = v.littleEndian
            header.append(Data(bytes: &le, count: 4))
        }
        func appendU16(_ v: UInt16) {
            var le = v.littleEndian
            header.append(Data(bytes: &le, count: 2))
        }

        appendASCII("RIFF")
        appendU32(36 + dataSize)
        appendASCII("WAVE")
        appendASCII("fmt ")
        appendU32(16)
        appendU16(1) // PCM
        appendU16(channels)
        appendU32(sampleRate)
        appendU32(byteRate)
        appendU16(blockAlign)
        appendU16(bitsPerSample)
        appendASCII("data")
        appendU32(dataSize)
        return header + pcm
    }
}

/// Shared HTTP helpers for cloud ASR plug-ins.
enum RemoteASRHTTP {
    static func post(
        url: URL,
        headers: [String: String],
        body: Data,
        contentType: String
    ) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        for (k, v) in headers {
            req.setValue(v, forHTTPHeaderField: k)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ASREngineError.underlying("Invalid HTTP response")
        }
        return (data, http)
    }
}
