import Foundation

/// Stub VLM screen parser — Phase 3+. No ScreenCaptureKit wiring yet.
///
/// Privacy: if/when wired in-process, this type receives `CapturedFrame` pixels.
/// Retention rules in core are software policy only — a buggy parser can keep
/// copies. OS-enforced isolation requires XPC parse-only (docs/PRIVACY.md).
public final class QuantizedVLMParser: ScreenContextParser, @unchecked Sendable {
    public static let manifestID = "screen.vlm.quantized"
    public let manifest = PluginManifest(
        id: manifestID,
        name: "Quantized VLM",
        kind: .screenContext,
        summary: "Stub — downsample frame ≤768px → CoreML VLM → discard pixels.",
        approxActiveMemoryMB: 200,
        requiresNetwork: false
    )
    public private(set) var isActive = false

    public init() {}

    public func activate() async throws { isActive = true }
    public func deactivate() async { isActive = false }

    public func parse(_ frame: CapturedFrame) async throws -> ScreenContext {
        _ = frame
        return .empty
    }
}
