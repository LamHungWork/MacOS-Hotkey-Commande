import Cocoa
import os

/// The buttons on screen while the Activation Hotkey is held.
final class DeckPanelController {
    /// Called with the id of the button that was clicked.
    var onClick: ((String) -> Void)?

    private let configManager: ConfigurationManager
    private let iconStore: IconStore
    private let panel = DeckPanel()

    init(configManager: ConfigurationManager, iconStore: IconStore) {
        self.configManager = configManager
        self.iconStore = iconStore
        reload()
    }

    /// Builds the whole panel ahead of time, so showing it is only a matter of ordering it in.
    func reload() {
        hide()

        let buttons = configManager.getShortcuts().map { shortcut in
            DeckView.Button(
                id: shortcut.id,
                face: ButtonFace(name: shortcut.name ?? "", key: shortcut.key, icon: shortcut.icon.flatMap(iconStore.image(named:)))
            )
        }
        let view = DeckView(buttons: buttons)
        view.onClick = { [weak self] id in
            self?.onClick?(id)
        }
        panel.setContentSize(view.frame.size)
        panel.contentView = view

        // Ordered in once, unseen, so macOS has its window and its first drawing ready.
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.displayIfNeeded()
        panel.invalidateShadow()
        CATransaction.flush()
        panel.orderOut(nil)
        panel.alphaValue = 1
    }

    /// `time` is when the hotkey was completed, in seconds since the Mac started.
    func show(hotkeyAt time: TimeInterval) {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }) ?? NSScreen.main else {
            return
        }

        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: (screen.frame.midX - size.width / 2).rounded(),
            y: (screen.frame.midY - size.height / 2).rounded()
        ))
        (panel.contentView as? DeckView)?.willShow()
        panel.orderFrontRegardless()
        panel.displayIfNeeded()
        CATransaction.flush()

        let milliseconds = (ProcessInfo.processInfo.systemUptime - time) * 1000
        Logger.app.notice("panel shown \(milliseconds, format: .fixed(precision: 1), privacy: .public) ms after the hotkey")
    }

    func hide() {
        (panel.contentView as? DeckView)?.willHide()
        panel.orderOut(nil)
    }
}

/// Floats over everything, full-screen apps included, and never takes the keyboard focus.
private final class DeckPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .none
        worksWhenModal = true
        allowsToolTipsWhenApplicationIsInactive = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
}

/// Draws the buttons and takes the clicks.
final class DeckView: NSView {
    struct Button {
        let id: String
        let face: ButtonFace
    }

    var onClick: ((String) -> Void)?

    private static let columns = 8
    private static let cell: CGFloat = 124 // a 112 pt button and half the gap on each side
    private static let margin: CGFloat = 15 // 14 pt and the border
    private static let emptyText = NSAttributedString(
        string: "Add buttons in Configure…",
        attributes: [.font: NSFont.systemFont(ofSize: 15), .foregroundColor: DeckColor.text]
    )

    private let buttons: [Button]
    private var hovered: Int?
    private var pressed: Int?
    private var pointerArea: NSTrackingArea?

    init(buttons: [Button]) {
        self.buttons = buttons
        super.init(frame: NSRect(origin: .zero, size: Self.size(for: buttons.count)))
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func size(for count: Int) -> NSSize {
        guard count > 0 else {
            return NSSize(width: ceil(emptyText.size().width) + 58, height: 60)
        }
        let columns = min(count, Self.columns)
        let rows = (count + Self.columns - 1) / Self.columns
        return NSSize(width: CGFloat(columns) * cell + margin * 2, height: CGFloat(rows) * cell + margin * 2)
    }

    private func cellRect(_ index: Int) -> NSRect {
        return NSRect(
            x: Self.margin + CGFloat(index % Self.columns) * Self.cell,
            y: Self.margin + CGFloat(index / Self.columns) * Self.cell,
            width: Self.cell,
            height: Self.cell
        )
    }

    /// A cell reaches halfway into the gaps around its button, so a click in a gap finds the nearest one.
    private func index(at event: NSEvent) -> Int? {
        let point = convert(event.locationInWindow, from: nil)
        return buttons.indices.first { cellRect($0).contains(point) }
    }

    // MARK: - Drawing

    override var isFlipped: Bool { return true }

    override func draw(_ dirtyRect: NSRect) {
        let radius: CGFloat = buttons.isEmpty ? 20 : 26
        let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: radius - 0.5, yRadius: radius - 0.5)
        DeckColor.panel.setFill()
        outline.fill()
        DeckColor.panelBorder.setStroke()
        outline.stroke()

        if buttons.isEmpty {
            let size = Self.emptyText.size()
            Self.emptyText.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2))
        }

        for (index, button) in buttons.enumerated() {
            let cell = cellRect(index)
            guard cell.intersects(dirtyRect) else { continue }
            let state: ButtonFace.State = index == pressed ? .pressed : index == hovered ? .hover : .normal
            button.face.draw(in: cell.insetBy(dx: 6, dy: 6), metrics: .panel, state: state)
        }
    }

    private func setHovered(_ index: Int?) {
        guard index != hovered else { return }
        let changed = [hovered, index]
        hovered = index
        redraw(changed)
    }

    private func setPressed(_ index: Int?) {
        guard index != pressed else { return }
        let changed = [pressed, index]
        pressed = index
        redraw(changed)
    }

    private func redraw(_ indexes: [Int?]) {
        for case let index? in indexes {
            setNeedsDisplay(cellRect(index))
        }
    }

    // MARK: - Pointer

    func reset() {
        setHovered(nil)
        setPressed(nil)
    }

    /// A tooltip on screen would outlive the panel by most of a second, so it goes first.
    func willHide() {
        removeAllToolTips()
        reset()
    }

    /// The panel can show right under the pointer.
    func willShow() {
        removeAllToolTips()
        for (index, button) in buttons.enumerated() where !button.face.name.isEmpty {
            addToolTip(cellRect(index), owner: self, userData: nil)
        }

        guard let window = window else { return }
        let point = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        setHovered(buttons.indices.first { cellRect($0).contains(point) })

        if let pointerArea = pointerArea {
            removeTrackingArea(pointerArea)
        }
        var options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways]
        if bounds.contains(point) {
            options.insert(.assumeInside)
        }
        let area = NSTrackingArea(rect: bounds, options: options, owner: self)
        addTrackingArea(area)
        pointerArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        setHovered(index(at: event))
    }

    override func mouseMoved(with event: NSEvent) {
        setHovered(index(at: event))
    }

    override func mouseExited(with event: NSEvent) {
        reset()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    // With Control held a click can arrive as either button.
    override func mouseDown(with event: NSEvent) { press(event) }
    override func rightMouseDown(with event: NSEvent) { press(event) }
    override func mouseDragged(with event: NSEvent) { drag(event) }
    override func rightMouseDragged(with event: NSEvent) { drag(event) }
    override func mouseUp(with event: NSEvent) { setPressed(nil) }
    override func rightMouseUp(with event: NSEvent) { setPressed(nil) }

    private func press(_ event: NSEvent) {
        guard let index = index(at: event) else { return }
        setPressed(index)
        onClick?(buttons[index].id)
    }

    private func drag(_ event: NSEvent) {
        let index = index(at: event)
        setHovered(index)
        if index != pressed {
            setPressed(nil)
        }
    }
}

extension DeckView: NSViewToolTipOwner {
    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        guard let index = buttons.indices.first(where: { cellRect($0).contains(point) }) else { return "" }
        return buttons[index].face.name
    }
}
