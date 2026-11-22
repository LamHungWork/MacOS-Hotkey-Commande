import Cocoa

/// The buttons in Settings, laid out like the panel, with a "+" after the last one.
final class ButtonGridView: NSView {
    struct Tile {
        let id: String
        let face: ButtonFace
        let isSelected: Bool
        let isInvalid: Bool
        let toolTip: String
    }

    var onSelect: ((String) -> Void)?
    var onAdd: (() -> Void)?
    var onMove: ((String, Int) -> Void)?
    /// A file dropped on a button, or on "+" when the id is nil.
    var onDrop: ((String?, URL) -> Void)?

    static let columns = 8
    static let cell: CGFloat = 88
    static let padding: CGFloat = 8
    static let width = CGFloat(columns) * cell + padding * 2

    static func height(for count: Int) -> CGFloat {
        let rows = (count + columns) / columns // one more tile for "+"
        return CGFloat(rows) * cell + padding * 2
    }

    private static let buttonType = NSPasteboard.PasteboardType("com.hotkeycommander.button")

    private enum DropMark: Equatable {
        case file(Int)
        case move(from: Int, to: Int)
    }

    private var dropMark: DropMark? {
        didSet {
            if dropMark != oldValue {
                needsDisplay = true
            }
        }
    }
    private var pressPoint: NSPoint?
    private var pressIndex: Int?

    var tiles: [Tile] = [] {
        didSet {
            setFrameSize(NSSize(width: Self.width, height: Self.height(for: tiles.count)))
            removeAllToolTips()
            for index in tiles.indices {
                addToolTip(cellRect(index), owner: self, userData: nil)
            }
            needsDisplay = true
        }
    }

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.height(for: 0)))
        registerForDraggedTypes([.fileURL, Self.buttonType])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { return true }

    private func cellRect(_ index: Int) -> NSRect {
        return NSRect(
            x: Self.padding + CGFloat(index % Self.columns) * Self.cell,
            y: Self.padding + CGFloat(index / Self.columns) * Self.cell,
            width: Self.cell,
            height: Self.cell
        )
    }

    /// `tiles.count` is "+".
    private func index(at windowPoint: NSPoint) -> Int? {
        let point = convert(windowPoint, from: nil)
        return (0...tiles.count).first { cellRect($0).contains(point) }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        for (index, tile) in tiles.enumerated() {
            draw(tile, at: index)
        }
        drawAddTile()

        if case .move(let from, let to) = dropMark, from != to {
            let cell = cellRect(to)
            NSColor(hex: 0xF59E0B).setFill()
            NSRect(x: to < from ? cell.minX : cell.maxX - 3, y: cell.minY, width: 3, height: cell.height).fill()
        }
    }

    private func draw(_ tile: Tile, at index: Int) {
        let rect = cellRect(index).insetBy(dx: 4, dy: 4)
        let isDropTarget = dropMark == .file(index)
        tile.face.draw(in: rect, metrics: .grid, state: isDropTarget ? .hover : .normal)

        if tile.isSelected || isDropTarget {
            let radius = ButtonMetrics.grid.radius - 1
            let ring = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: radius, yRadius: radius)
            ring.lineWidth = 2
            NSColor(hex: tile.isSelected ? 0x5AA2FF : 0xD5D8DF).setStroke()
            ring.stroke()
        }

        if tile.isInvalid {
            let badge = NSRect(x: rect.minX + 4, y: rect.minY + 4, width: 17, height: 17)
            NSColor(hex: 0xFFB4AE).setFill()
            NSBezierPath(ovalIn: badge).fill()
            let mark = NSAttributedString(string: "!", attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor(hex: 0x5A0F0A)
            ])
            let size = mark.size()
            mark.draw(at: NSPoint(x: badge.midX - size.width / 2, y: badge.midY - size.height / 2))
        }
    }

    private func drawAddTile() {
        let rect = cellRect(tiles.count).insetBy(dx: 4, dy: 4)
        let radius = ButtonMetrics.grid.radius - 0.75
        let outline = NSBezierPath(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), xRadius: radius, yRadius: radius)
        outline.lineWidth = 1.5
        outline.setLineDash([4.5, 4.5], count: 2, phase: 0)
        NSColor(hex: dropMark == .file(tiles.count) ? 0xD5D8DF : 0x7C828E).setStroke()
        outline.stroke()

        let plus = NSBezierPath()
        plus.move(to: NSPoint(x: rect.midX, y: rect.midY - 7))
        plus.line(to: NSPoint(x: rect.midX, y: rect.midY + 7))
        plus.move(to: NSPoint(x: rect.midX - 7, y: rect.midY))
        plus.line(to: NSPoint(x: rect.midX + 7, y: rect.midY))
        plus.lineWidth = 1.8
        plus.lineCapStyle = .round
        NSColor(hex: 0xD5D8DF).setStroke()
        plus.stroke()
    }

    // MARK: - Clicking and dragging a button

    override func mouseDown(with event: NSEvent) {
        pressIndex = index(at: event.locationInWindow)
        pressPoint = event.locationInWindow
        if let index = pressIndex, index < tiles.count {
            onSelect?(tiles[index].id)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let index = pressIndex, index < tiles.count, let start = pressPoint,
              hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) > 4 else {
            return
        }
        pressIndex = nil

        let item = NSPasteboardItem()
        item.setString(tiles[index].id, forType: Self.buttonType)
        let dragging = NSDraggingItem(pasteboardWriter: item)
        dragging.setDraggingFrame(cellRect(index).insetBy(dx: 4, dy: 4), contents: snapshot(of: tiles[index].face))
        beginDraggingSession(with: [dragging], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        if pressIndex == tiles.count, index(at: event.locationInWindow) == tiles.count {
            onAdd?()
        }
        pressIndex = nil
    }

    private func snapshot(of face: ButtonFace) -> NSImage {
        let size = NSSize(width: Self.cell - 8, height: Self.cell - 8)
        return NSImage(size: size, flipped: true) { rect in
            face.draw(in: rect, metrics: .grid)
            return true
        }
    }

    // MARK: - Dropping

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropMark = mark(for: sender)
        guard let mark = dropMark else { return [] }

        switch mark {
        case .file(let index):
            scrollToVisible(cellRect(index).insetBy(dx: 0, dy: -20))
            return .copy
        case .move(_, let index):
            scrollToVisible(cellRect(index).insetBy(dx: 0, dy: -20))
            return .move
        }
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropMark = nil
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        dropMark = nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let mark = self.mark(for: sender)
        dropMark = nil

        switch mark {
        case .file(let index)?:
            guard let file = IconDrop.file(in: sender.draggingPasteboard) else { return false }
            onDrop?(index < tiles.count ? tiles[index].id : nil, file)
            return true
        case .move(let from, let to)?:
            onMove?(tiles[from].id, to)
            return true
        case nil:
            return false
        }
    }

    private func mark(for info: NSDraggingInfo) -> DropMark? {
        guard let index = index(at: info.draggingLocation) else { return nil }

        if (info.draggingSource as? ButtonGridView) === self {
            guard index < tiles.count,
                  let id = info.draggingPasteboard.string(forType: Self.buttonType),
                  let from = tiles.firstIndex(where: { $0.id == id }) else {
                return nil
            }
            return .move(from: from, to: index)
        }

        return IconDrop.file(in: info.draggingPasteboard) == nil ? nil : .file(index)
    }
}

extension ButtonGridView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return context == .withinApplication ? .move : []
    }
}

extension ButtonGridView: NSViewToolTipOwner {
    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        guard let index = tiles.indices.first(where: { cellRect($0).contains(point) }) else { return "" }
        return tiles[index].toolTip
    }
}

/// Keeps the thin scroller. With a mouse attached macOS switches to the wide one, which takes its width
/// from the grid and cuts the last column.
final class OverlayScrollView: NSScrollView {
    override var scrollerStyle: NSScroller.Style {
        get { return .overlay }
        set { super.scrollerStyle = .overlay }
    }
}

/// The selected button as it looks on the panel. Takes an icon by drop or by click.
final class ButtonPreviewView: NSView {
    var onDrop: ((URL) -> Void)?
    var onClick: (() -> Void)?

    static let size = NSSize(width: 152, height: 132)

    var face: ButtonFace? {
        didSet { needsDisplay = true }
    }

    private var isDropTarget = false {
        didSet { needsDisplay = true }
    }

    init() {
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        registerForDraggedTypes([.fileURL])
        toolTip = "Drop an image or an app, or click to choose"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { return true }
    override var intrinsicContentSize: NSSize { return Self.size }

    override func draw(_ dirtyRect: NSRect) {
        DeckColor.panel.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 18, yRadius: 18).fill()
        face?.draw(in: bounds.insetBy(dx: 20, dy: 10), metrics: .panel, state: isDropTarget ? .hover : .normal)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            onClick?()
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isDropTarget = IconDrop.file(in: sender.draggingPasteboard) != nil
        return isDropTarget ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDropTarget = false
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        isDropTarget = false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDropTarget = false
        guard let file = IconDrop.file(in: sender.draggingPasteboard) else { return false }
        onDrop?(file)
        return true
    }
}

/// The first file in a drag that can be an icon.
enum IconDrop {
    static func file(in pasteboard: NSPasteboard) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: IconStore.fileTypes.map(\.identifier)
        ]
        return (pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL])?.first
    }
}
