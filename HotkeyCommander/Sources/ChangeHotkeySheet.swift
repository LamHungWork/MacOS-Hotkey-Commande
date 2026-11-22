import Cocoa

/// Asks for a new Activation Hotkey.
final class ChangeHotkeySheet: NSWindow {
    private let field = NSTextField(labelWithString: "Press modifiers...")
    private let okButton = NSButton(title: "OK", target: nil, action: nil)
    private var monitor: Any?
    private var held: NSEvent.ModifierFlags = []
    private var captured: NSEvent.ModifierFlags = []

    /// Returns the new combination, or nil when cancelled.
    private var completion: (([String]?) -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 390, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        setupUI()
    }

    func begin(on window: NSWindow, completion: @escaping ([String]?) -> Void) {
        self.completion = completion
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.modifiersChanged(to: event.modifierFlags)
            return event
        }
        window.beginSheet(self)
    }

    /// Keeps what was pressed after the keys are let go. The next press starts a new combination.
    private func modifiersChanged(to flags: NSEvent.ModifierFlags) {
        let now = flags.intersection([.control, .shift, .command, .option])
        if !now.isEmpty {
            captured = held.isEmpty ? now : captured.union(now)
        }
        held = now

        guard !captured.isEmpty else { return }
        field.stringValue = ModifierNames.text(for: ModifierNames.names(in: captured))
        field.textColor = .labelColor
        field.font = .systemFont(ofSize: 13, weight: .semibold)
        okButton.isEnabled = true
    }

    @objc private func confirm() {
        finish(with: ModifierNames.names(in: captured))
    }

    @objc private func cancel() {
        finish(with: nil)
    }

    private func finish(with modifiers: [String]?) {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        sheetParent?.endSheet(self)
        orderOut(nil)
        completion?(modifiers)
        completion = nil
    }

    private func setupUI() {
        let title = NSTextField(labelWithString: "Press New Hotkey Combination")
        title.font = .systemFont(ofSize: 15, weight: .semibold)

        let info = NSTextField(wrappingLabelWithString: "Press the modifier keys you want to use (Control, Shift, Command, Option)")
        info.font = .systemFont(ofSize: 12)
        info.textColor = .secondaryLabelColor
        info.isSelectable = false
        info.preferredMaxLayoutWidth = 342

        field.textColor = .secondaryLabelColor
        let holder = NSView()
        field.translatesAutoresizingMaskIntoConstraints = false
        holder.addSubview(field)
        let box = FieldBox(content: holder, insets: NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12))
        box.isFocused = true

        okButton.target = self
        okButton.action = #selector(confirm)
        okButton.keyEquivalent = "\r"
        okButton.isEnabled = false
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [spacer, cancelButton, okButton])
        buttons.spacing = 10
        buttons.distribution = .fill

        let stack = NSStackView(views: [title, info, box, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        contentView = content
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.widthAnchor.constraint(equalToConstant: 390),
            field.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
            field.centerYAnchor.constraint(equalTo: holder.centerYAnchor),
            box.heightAnchor.constraint(equalToConstant: 40),
            box.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),
            cancelButton.widthAnchor.constraint(equalToConstant: 92),
            okButton.widthAnchor.constraint(equalToConstant: 92)
        ])
    }
}
