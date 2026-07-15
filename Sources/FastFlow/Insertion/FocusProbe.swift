import AppKit
import ApplicationServices
import Foundation
import FastFlowPlugins

/// Cheap, event-driven focus capture via Accessibility (Options A & B).
@MainActor
enum FocusProbe {
    /// AX roles we treat as valid text-input targets.
    static let textInputRoles: Set<String> = [
        "AXTextField",
        "AXTextArea",
        "AXComboBox",
        "AXSearchField",
        "AXTextView",
        "AXEditableText",
    ]

    static func captureSnapshot() -> FocusSnapshot? {
        let system = AXUIElementCreateSystemWide()
        var focusedObj: AnyObject?
        let focusStatus = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObj
        )
        guard focusStatus == .success, let focused = focusedObj else {
            return snapshotFromFrontmostAppOnly()
        }
        let element = focused as! AXUIElement
        return snapshot(from: element)
    }

    static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focusedObj: AnyObject?
        let status = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObj
        )
        guard status == .success, let focused = focusedObj else { return nil }
        return (focused as! AXUIElement)
    }

    static func snapshot(from element: AXUIElement) -> FocusSnapshot {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)

        let role = stringAttribute(element, kAXRoleAttribute as String)
        let subrole = stringAttribute(element, kAXSubroleAttribute as String)
        let title = stringAttribute(element, kAXTitleAttribute as String)
            ?? stringAttribute(element, kAXDescriptionAttribute as String)
        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        let isText = isTextInput(role: role, subrole: subrole, element: element)
        let token = identityToken(
            pid: pid,
            role: role,
            subrole: subrole,
            title: title,
            element: element
        )

        return FocusSnapshot(
            pid: Int32(pid),
            bundleID: bundleID,
            role: role,
            subrole: subrole,
            title: title,
            isTextInput: isText,
            identityToken: token,
            capturedAt: .now
        )
    }

    static func isTextInput(role: String?, subrole: String?, element: AXUIElement) -> Bool {
        if let role, textInputRoles.contains(role) { return true }
        if subrole == "AXSearchField" { return true }
        // Editable?
        var settable: DarwinBoolean = false
        let status = AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &settable
        )
        return status == .success && settable.boolValue
    }

    // MARK: - Private

    private static func snapshotFromFrontmostAppOnly() -> FocusSnapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return FocusSnapshot(
            pid: Int32(app.processIdentifier),
            bundleID: app.bundleIdentifier,
            role: nil,
            subrole: nil,
            title: app.localizedName,
            isTextInput: false,
            identityToken: "app-only:\(app.processIdentifier)",
            capturedAt: .now
        )
    }

    private static func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        var value: AnyObject?
        let status = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard status == .success else { return nil }
        return value as? String
    }

    private static func identityToken(
        pid: pid_t,
        role: String?,
        subrole: String?,
        title: String?,
        element: AXUIElement
    ) -> String {
        var positionDesc = "?"
        var posValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
           let axValue = posValue
        {
            var point = CGPoint.zero
            if AXValueGetValue(axValue as! AXValue, .cgPoint, &point) {
                positionDesc = String(format: "%.0f,%.0f", point.x, point.y)
            }
        }
        return [
            "pid:\(pid)",
            "role:\(role ?? "")",
            "sub:\(subrole ?? "")",
            "title:\(title ?? "")",
            "pos:\(positionDesc)",
        ].joined(separator: "|")
    }
}
