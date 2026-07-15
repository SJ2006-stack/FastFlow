import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Global push-to-talk hotkey via CGEventTap (default: Right Option).
final class HotkeyMonitor: @unchecked Sendable {
    struct Choice: Equatable {
        let name: String
        let keycode: CGKeyCode
        let isModifier: Bool
        let modifierFlag: CGEventFlags?
    }

    static let rightOption = Choice(
        name: "Right Option",
        keycode: 61,
        isModifier: true,
        modifierFlag: .maskAlternate
    )

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let choice: Choice
    private var isDown = false

    var onDown: (() -> Void)?
    var onUp: (() -> Void)?

    init(choice: Choice = HotkeyMonitor.rightOption) {
        self.choice = choice
    }

    func start() throws {
        guard AXIsProcessTrusted() else {
            throw HotkeyError.accessibilityRequired
        }

        let mask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw HotkeyError.tapFailed
        }

        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        let keycode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        if choice.isModifier, type == .flagsChanged, keycode == choice.keycode {
            let flag = choice.modifierFlag ?? []
            let down = event.flags.contains(flag)
            if down, !isDown {
                isDown = true
                DispatchQueue.main.async { self.onDown?() }
            } else if !down, isDown {
                isDown = false
                DispatchQueue.main.async { self.onUp?() }
            }
            return
        }

        guard !choice.isModifier, keycode == choice.keycode else { return }
        if type == .keyDown, !event.flags.contains(.maskSecondaryFn) {
            if !isDown {
                isDown = true
                DispatchQueue.main.async { self.onDown?() }
            }
        } else if type == .keyUp, isDown {
            isDown = false
            DispatchQueue.main.async { self.onUp?() }
        }
    }
}

enum HotkeyError: LocalizedError {
    case accessibilityRequired
    case tapFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired:
            return "Accessibility permission is required for the global hotkey."
        case .tapFailed:
            return "Failed to create CGEventTap (Input Monitoring / Accessibility)."
        }
    }
}
