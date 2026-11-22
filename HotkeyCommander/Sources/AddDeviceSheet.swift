import Cocoa
import CoreImage

/// Asks for a name, then shows the code the phone scans. The device is saved as soon as the code shows.
final class AddDeviceSheet: NSWindow, NSTextFieldDelegate {
    private let phones: PhoneController
    private let nameField = FocusTextField()
    private let okButton = NSButton(title: "OK", target: nil, action: nil)

    private static let width: CGFloat = 342
    private static let margin: CGFloat = 24

    init(phones: PhoneController) {
        self.phones = phones
        super.init(contentRect: NSRect(x: 0, y: 0, width: 390, height: 160), styleMask: [.titled], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        showNameStep()
    }

    func begin(on window: NSWindow) {
        window.beginSheet(self)
        makeFirstResponder(nameField)
    }

    func controlTextDidChange(_ obj: Notification) {
        okButton.isEnabled = !name.isEmpty
    }

    private var name: String {
        return nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @objc private func confirm() {
        guard !name.isEmpty else { return }
        showCodeStep(link: phones.addDevice(named: name))
    }

    @objc private func finish() {
        sheetParent?.endSheet(self)
        orderOut(nil)
    }

    // MARK: - Steps

    private func showNameStep() {
        nameField.delegate = self
        let box = FieldBox(field: nameField, height: 32)

        okButton.target = self
        okButton.action = #selector(confirm)
        okButton.keyEquivalent = "\r"
        okButton.isEnabled = false
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(finish))
        cancelButton.keyEquivalent = "\u{1b}"

        show([title("Add Device"), NSTextField(labelWithString: "Name"), box, row([cancelButton, okButton])], wide: [box])
    }

    private func showCodeStep(link: String) {
        let code = NSImageView()
        code.image = Self.code(for: link)
        code.imageScaling = .scaleNone

        let info = NSTextField(wrappingLabelWithString: "Scan this code with your phone's camera.")
        info.font = .systemFont(ofSize: 12)
        info.textColor = .secondaryLabelColor
        info.isSelectable = false

        let doneButton = NSButton(title: "Done", target: self, action: #selector(finish))
        doneButton.keyEquivalent = "\r"

        let holder = NSStackView(views: [code])
        holder.alignment = .centerX
        holder.orientation = .vertical
        show([title(name), info, holder, row([doneButton])], wide: [holder])
    }

    private func show(_ views: [NSView], wide: [NSView]) {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Self.margin),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.margin),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Self.margin),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Self.margin),
            stack.widthAnchor.constraint(equalToConstant: Self.width)
        ])
        for view in wide + views.suffix(1) {
            view.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        }
        contentView = content
        content.layoutSubtreeIfNeeded()
        setContentSize(content.fittingSize)
    }

    private func title(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    private func row(_ buttons: [NSButton]) -> NSStackView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for button in buttons {
            button.widthAnchor.constraint(equalToConstant: 92).isActive = true
        }
        let stack = NSStackView(views: [spacer] + buttons)
        stack.spacing = 10
        stack.distribution = .fill
        return stack
    }

    /// Black on white with a margin, whatever the appearance: that is what cameras read.
    private static func code(for link: String) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(link.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage,
              let code = CIContext().createCGImage(output, from: output.extent) else {
            return nil
        }

        let side: CGFloat = 260
        let module = floor(side / CGFloat(code.width + 4))
        let drawn = module * CGFloat(code.width)
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
            NSGraphicsContext.current?.imageInterpolation = .none
            NSGraphicsContext.current?.cgContext.draw(
                code, in: CGRect(x: (side - drawn) / 2, y: (side - drawn) / 2, width: drawn, height: drawn)
            )
            return true
        }
    }
}
