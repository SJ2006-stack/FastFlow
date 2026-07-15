import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Global push-to-talk via CGEventTap.
/// Default preset: **Spacebar** (hold to talk). Events are swallowed so Space isn’t typed while dictating.
final class HotkeyMonitor: @unchecked Sendable {
    struct Preset: Equatable, Sendable {
        let id: String
        let name: String
        let keycode: CGKeyCode
        let isModifier: Bool
        let modifierFlag: CGEventFlags?
        /// When true, the tap consumes the key so it doesn’t reach the focused app.
        let swallowEvents: Bool

        static let space = Preset(
            id: "space",
            name: "Spacebar (hold)",
            keycode: 49,
            isModifier: false,
            modifierFlag: nil,
            swallowEvents: true
        )

        static let rightOption = Preset(
            id: "rightOption",
            name: "Right Option (hold)",
            keycode: 61,
            isModifier: true,
            modifierFlag: .maskAlternate,
            swallowEvents: false
        )

        static let leftOption = Preset(
            id: "leftOption",
            name: "Left Option (hold)",
            keycode: 58,
            isModifier: true,
            modifierFlag: .maskAlternate,
            swallowEvents: false
        )

        static let rightCommand = Preset(
            id: "rightCommand",
            name: "Right ⌘ (hold)",
            keycode: 54,
            isModifier: true,
            modifierFlag: .maskCommand,
            swallowEvents: false
        )

        static let f5 = Preset(
            id: "f5",
            name: "F5 (hold)",
            keycode: 96,
            isModifier: false,
            modifierFlag: nil,
            swallowEvents: true
        )

        static let all: [Preset] = [.space, .rightOption, .leftOption, .rightCommand, .f5]
    }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var choice: Preset
    private var isDown = false

    var onDown: (() -> Void)?
    var onUp: (() -> Void)?

    var currentPreset: Preset { choice }

    init(choice: Preset = HotkeyPreferences.currentPreset) {
        self.choice = choice
    }

    func start() throws {
        stop()
        guard AXIsProcessTrusted() else {
            throw HotkeyError.accessibilityRequired
        }

        let mask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        // Swallow Space / F5 so they don’t type into the focused field while PTT is held.
        let options: CGEventTapOptions = choice.swallowEvents ? .defaultTap : .listenOnly

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            let consume = monitor.handle(type: type, event: event)
            if consume {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: options,
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
        isDown = false
    }

    func applyPreset(_ preset: Preset) throws {
        choice = preset
        HotkeyPreferences.presetID = preset.id
        try start()
    }

    /// Returns true if the event should be swallowed.
    @discardableResult
    private func handle(type: CGEventType, event: CGEvent) -> Bool {
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
            return choice.swallowEvents
        }

        guard !choice.isModifier, keycode == choice.keycode else { return false }

        // Ignore key-repeat while already down.
        if type == .keyDown {
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if isRepeat { return choice.swallowEvents }
            if !isDown {
                isDown = true
                DispatchQueue.main.async { self.onDown?() }
            }
            return choice.swallowEvents
        }
        if type == .keyUp, isDown {
            isDown = false
            DispatchQueue.main.async { self.onUp?() }
            return choice.swallowEvents
        }
        return false
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
