import Cocoa

/// The frame around a text field in Settings: plain, focused, or red when its value is not valid.
final class FieldBox: NSView {
    var isInvalid = false {
        didSet { needsDisplay = true }
    }

    var isFocused = false {
        didSet { needsDisplay = true }
    }

    static let red = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(hex: 0xFF6961) : NSColor(hex: 0xC4231C)
    }

    init(content: NSView, insets: NSEdgeInsets) {
        super.init(frame: .zero)
        wantsLayer = true
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom)
        ])
    }

    /// A one-line field, centred in a box of the given height.
    convenience init(field: FocusTextField, height: CGFloat) {
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.cell?.wraps = false

        let holder = NSView()
        field.translatesAutoresizingMaskIntoConstraints = false
        holder.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
            field.centerYAnchor.constraint(equalTo: holder.centerYAnchor)
        ])
        self.init(content: holder, insets: NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8))
        heightAnchor.constraint(equalToConstant: height).isActive = true
        field.onFocus = { [weak self] focused in
            self?.isFocused = focused
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var wantsUpdateLayer: Bool { return true }

    override func updateLayer() {
        layer?.cornerRadius = 7
        layer?.borderWidth = isFocused ? 2 : 1
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        let border: NSColor = isInvalid ? Self.red : isFocused ? .controlAccentColor : .separatorColor
        layer?.borderColor = border.cgColor
    }
}

final class FocusTextField: NSTextField {
    var onFocus: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            onFocus?(true)
        }
        return accepted
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        onFocus?(false)
    }
}

/// The Key field's editor. Its text is replaced while it is being typed, so there is nothing in it that
/// could be undone, and ⌘Z there must not undo in another field either.
final class KeyFieldEditor: NSTextView {
    private let noUndo = UndoManager()

    override var undoManager: UndoManager? {
        return noUndo
    }

    static func make() -> KeyFieldEditor {
        let editor = KeyFieldEditor()
        editor.isFieldEditor = true
        return editor
    }
}

/// Holds a script, so nothing the user types is turned into something else.
final class CommandTextView: NSTextView {
    var onFocus: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            onFocus?(true)
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted {
            onFocus?(false)
        }
        return accepted
    }

    /// The text view in a scroll view of its own.
    static func make() -> (scrollView: NSScrollView, textView: CommandTextView) {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = CommandTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 88))
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = false
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .textColor
        textView.textContainerInset = NSSize(width: 3, height: 6)

        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = 18
        style.maximumLineHeight = 18
        textView.defaultParagraphStyle = style
        textView.typingAttributes[.paragraphStyle] = style

        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        return (scrollView, textView)
    }
}
