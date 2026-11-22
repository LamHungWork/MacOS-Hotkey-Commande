import Cocoa

/// The colours of the panel and of everything that shows its buttons.
enum DeckColor {
    static let panel = NSColor(hex: 0x1C1D21)
    static let panelBorder = NSColor(hex: 0x44474F)
    static let button = NSColor(hex: 0x2A2C32)
    static let buttonHover = NSColor(hex: 0x3C3F48)
    static let buttonPressed = NSColor(hex: 0x0F1012)
    static let text = NSColor(hex: 0xF1F2F5)
}

extension NSColor {
    convenience init(hex: Int) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// The measures of a button at one size.
struct ButtonMetrics {
    let radius: CGFloat
    let padding: CGFloat
    let name: CGFloat
    let nameLine: CGFloat
    let largeKey: CGFloat
    let badge: CGFloat
    let badgePadding: CGFloat
    let badgeRadius: CGFloat
    let badgeInset: CGFloat

    /// 112 pt.
    static let panel = ButtonMetrics(
        radius: 25, padding: 10, name: 15, nameLine: 19, largeKey: 40,
        badge: 20, badgePadding: 5, badgeRadius: 7, badgeInset: 8
    )

    /// 80 pt, with the panel's proportions.
    static let grid = ButtonMetrics(
        radius: 18, padding: 7, name: 13, nameLine: 16, largeKey: 30,
        badge: 17, badgePadding: 4, badgeRadius: 5, badgeInset: 5
    )
}

/// What a button shows. The panel, the Settings grid and the editor's preview all draw it from here.
struct ButtonFace {
    enum State {
        case normal, hover, pressed
    }

    let name: String
    let key: String
    let icon: NSImage?

    init(name: String, key: String, icon: NSImage?) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.key = key.uppercased()
        self.icon = icon
    }

    /// Draws in a flipped view.
    func draw(in rect: NSRect, metrics: ButtonMetrics, state: State = .normal) {
        let shape = NSBezierPath(roundedRect: rect, xRadius: metrics.radius, yRadius: metrics.radius)
        if let icon = icon {
            draw(icon, in: rect, shape: shape, state: state)
        } else {
            background(state).setFill()
            shape.fill()
            drawText(in: rect.insetBy(dx: metrics.padding, dy: 0), metrics: metrics)
        }

        if !key.isEmpty, icon != nil || !name.isEmpty {
            drawBadge(in: rect, metrics: metrics)
        }
    }

    private func background(_ state: State) -> NSColor {
        switch state {
        case .normal: return DeckColor.button
        case .hover: return DeckColor.buttonHover
        case .pressed: return DeckColor.buttonPressed
        }
    }

    /// Edge to edge. Grey shows through where the picture leaves the corners open.
    private func draw(_ icon: NSImage, in rect: NSRect, shape: NSBezierPath, state: State) {
        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
        DeckColor.button.setFill()
        rect.fill()
        icon.draw(
            in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high.rawValue]
        )
        if state != .normal {
            let veil: NSColor = state == .hover ? .white.withAlphaComponent(0.16) : .black.withAlphaComponent(0.35)
            veil.setFill()
            rect.fill(using: .sourceOver)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawText(in rect: NSRect, metrics: ButtonMetrics) {
        if name.isEmpty {
            drawLine(key, in: rect, font: .systemFont(ofSize: metrics.largeKey, weight: .semibold))
        } else {
            drawName(in: rect, metrics: metrics)
        }
    }

    /// At most two lines, cut with "…".
    private func drawName(in rect: NSRect, metrics: ButtonMetrics) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.minimumLineHeight = metrics.nameLine
        style.maximumLineHeight = metrics.nameLine
        let string = NSAttributedString(string: name, attributes: [
            .font: NSFont.systemFont(ofSize: metrics.name, weight: .semibold),
            .foregroundColor: DeckColor.text,
            .paragraphStyle: style
        ])
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        let limit = NSSize(width: rect.width, height: metrics.nameLine * 2)
        let height = min(limit.height, ceil(string.boundingRect(with: limit, options: options).height))
        string.draw(with: NSRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height), options: options)
    }

    private func drawBadge(in rect: NSRect, metrics: ButtonMetrics) {
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let textWidth = NSAttributedString(string: key, attributes: [.font: font]).size().width
        let width = max(metrics.badge, ceil(textWidth) + metrics.badgePadding * 2)
        let badge = NSRect(
            x: rect.maxX - metrics.badgeInset - width, y: rect.minY + metrics.badgeInset, width: width, height: metrics.badge
        )
        DeckColor.panel.setFill()
        NSBezierPath(roundedRect: badge, xRadius: metrics.badgeRadius, yRadius: metrics.badgeRadius).fill()
        drawLine(key, in: badge, font: font)
    }

    private func drawLine(_ text: String, in rect: NSRect, font: NSFont) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingTail
        let string = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: DeckColor.text, .paragraphStyle: style
        ])
        let height = ceil(string.size().height)
        string.draw(in: NSRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height))
    }
}
