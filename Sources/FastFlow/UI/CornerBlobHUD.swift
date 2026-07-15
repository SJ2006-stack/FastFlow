import AppKit
import Foundation

/// Tiny living blob docked to a screen corner so users always see FastFlow is present.
@MainActor
final class CornerBlobHUD {
    private var panel: NSPanel?
    private var blobView: BlobView?
    private var corner: BlobCorner
    private let size: CGFloat = 36
    private let margin: CGFloat = 18

    var onCornerChanged: ((BlobCorner) -> Void)?

    init(corner: BlobCorner = BlobPreferences.corner) {
        self.corner = corner
    }

    func show() {
        guard BlobPreferences.isVisible else {
            hide()
            return
        }
        if panel == nil {
            buildPanel()
        }
        reposition()
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func setCorner(_ corner: BlobCorner) {
        self.corner = corner
        BlobPreferences.corner = corner
        reposition()
        onCornerChanged?(corner)
    }

    func setState(_ state: MenuBarIconState) {
        blobView?.apply(state: state)
    }

    // MARK: - Private

    private func buildPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true

        let blob = BlobView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        blob.autoresizingMask = [.width, .height]
        blob.onClick = { [weak self] in
            self?.cycleCorner()
        }
        blob.onRightClick = { [weak self] in
            self?.showCornerMenu()
        }
        panel.contentView = blob

        self.panel = panel
        self.blobView = blob
    }

    private func reposition() {
        guard let panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin: CGPoint
        switch corner {
        case .topLeft:
            origin = CGPoint(x: visible.minX + margin, y: visible.maxY - size - margin)
        case .topRight:
            origin = CGPoint(x: visible.maxX - size - margin, y: visible.maxY - size - margin)
        case .bottomLeft:
            origin = CGPoint(x: visible.minX + margin, y: visible.minY + margin)
        case .bottomRight:
            origin = CGPoint(x: visible.maxX - size - margin, y: visible.minY + margin)
        }
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: size, height: size)), display: true)
    }

    private func cycleCorner() {
        let all = BlobCorner.allCases
        guard let idx = all.firstIndex(of: corner) else { return }
        let next = all[(idx + 1) % all.count]
        setCorner(next)
    }

    private func showCornerMenu() {
        let menu = NSMenu()
        for c in BlobCorner.allCases {
            let item = NSMenuItem(
                title: c.displayName,
                action: #selector(pickCorner(_:)),
                keyEquivalent: ""
            )
            item.representedObject = c.rawValue
            item.state = c == corner ? .on : .off
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let hide = NSMenuItem(title: "Hide blob", action: #selector(hideBlob), keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)

        if let panel {
            menu.popUp(positioning: nil, at: NSPoint(x: size / 2, y: 0), in: panel.contentView)
        }
    }

    @objc private func pickCorner(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let c = BlobCorner(rawValue: raw) else { return }
        setCorner(c)
    }

    @objc private func hideBlob() {
        BlobPreferences.isVisible = false
        hide()
    }
}

// MARK: - Blob drawing

@MainActor
final class BlobView: NSView {
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?

    private var fill = NSColor.systemTeal.withAlphaComponent(0.85)
    private var pulse: CGFloat = 0
    private var timer: Timer?
    private var listening = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        startIdlePulse()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func apply(state: MenuBarIconState) {
        switch state {
        case .idle:
            listening = false
            fill = NSColor.systemTeal.withAlphaComponent(0.9)
        case .listening:
            listening = true
            fill = NSColor.systemRed.withAlphaComponent(0.95)
        case .transcribing:
            listening = false
            fill = NSColor.systemOrange.withAlphaComponent(0.95)
        case .loading:
            listening = false
            fill = NSColor.systemBlue.withAlphaComponent(0.9)
        case .error:
            listening = false
            fill = NSColor.systemRed.withAlphaComponent(0.7)
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let inset = 3 + (listening ? pulse * 2 : pulse)
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let path = NSBezierPath(ovalIn: rect)
        fill.setFill()
        path.fill()

        // Soft inner highlight
        NSColor.white.withAlphaComponent(0.25).setFill()
        NSBezierPath(ovalIn: rect.insetBy(dx: rect.width * 0.28, dy: rect.height * 0.35)).fill()
    }

    override func mouseDown(with event: NSEvent) {
        if event.type == .rightMouseDown || event.modifierFlags.contains(.control) {
            onRightClick?()
        } else {
            onClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    private func startIdlePulse() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.pulse = (sin(Date().timeIntervalSinceReferenceDate * (self.listening ? 8 : 2.2)) + 1) * 0.5
                self.needsDisplay = true
            }
        }
    }

    deinit {
        timer?.invalidate()
    }
}
