import AppKit
import ApplicationServices
import AVFoundation
import Foundation

enum PermissionKind: String, CaseIterable {
    case microphone
    case accessibility
}

@MainActor
enum PermissionGate {
    static func microphoneAuthorized() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static func accessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings(for kind: PermissionKind) {
        let urlString: String
        switch kind {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    static func statusSummary() -> String {
        let mic = microphoneAuthorized() ? "✓" : "✗"
        let ax = accessibilityTrusted() ? "✓" : "✗"
        return "Mic \(mic)  Accessibility \(ax)"
    }
}
