import Cocoa
import UniformTypeIdentifiers

class ConfigurationWindowController: NSWindowController, NSWindowDelegate {
    var onSave: (() -> Void)?
    var onClose: (() -> Void)?

    private let configManager: ConfigurationManager
    private let iconStore: IconStore
    private let phoneController: PhoneController
    private let draft: SettingsDraft
    private var selectedID: String?

    // UI Components
    private let modifierButton = NSButton(title: "", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)
    private let grid = ButtonGridView()
    private let gridScrollView = OverlayScrollView()
    private let preview = ButtonPreviewView()
    private let removeIconButton = NSButton(title: "Remove icon", target: nil, action: nil)
    private let nameField = FocusTextField()
    private let keyField = FocusTextField()
    private let keyEditor = KeyFieldEditor.make()
    private let commandView: CommandTextView
    private let commandScrollView: NSScrollView
    private lazy var nameBox = FieldBox(field: nameField, height: 32)
    private lazy var keyBox = FieldBox(field: keyField, height: 32)
    private lazy var commandBox = FieldBox(content: commandScrollView, insets: NSEdgeInsets(top: 1, left: 1, bottom: 1, right: 1))
    private let keyError = ConfigurationWindowController.errorLabel()
    private let commandError = ConfigurationWindowController.errorLabel()
    private let faceError = ConfigurationWindowController.errorLabel()
    private let editor = NSView()
    private let emptyLabel = NSTextField(labelWithString: "Select a button to edit it.")
    private let tabs = NSSegmentedControl(labels: ["Buttons", "Phone"], trackingMode: .selectOne, target: nil, action: nil)
    private let buttonsTab = NSStackView()
    private lazy var phoneTab = PhoneSettingsView(phones: phoneController)
    private lazy var gridHeight = gridScrollView.heightAnchor.constraint(equalToConstant: ButtonGridView.height(for: 0))

    private static let margin: CGFloat = 20
    private static let width = ButtonGridView.width
    private static let maxGridHeight: CGFloat = 288
    private static let editorHeight: CGFloat = 274

    init(configManager: ConfigurationManager, iconStore: IconStore, phoneController: PhoneController) {
        self.configManager = configManager
        self.iconStore = iconStore
        self.phoneController = phoneController
        draft = SettingsDraft(configuration: configManager.getConfiguration(), iconStore: iconStore)
        selectedID = draft.buttons.first?.id
        (commandScrollView, commandView) = CommandTextView.make()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.width + Self.margin * 2, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Hotkey Commander Settings"
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self

        setupUI()
        showSelection()
        refresh()
        fitWindow()
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The panel stays away while a new Activation Hotkey is being pressed.
    var isChangingHotkey: Bool {
        return window?.attachedSheet is ChangeHotkeySheet
    }

    // MARK: - Layout

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let sections = [
            createHotkeySection(),
            createSeparator(),
            createGridSection(),
            createSeparator(),
            createEditorSection(),
            createButtonsSection()
        ]
        sections.forEach(buttonsTab.addArrangedSubview)
        buttonsTab.orientation = .vertical
        buttonsTab.alignment = .leading
        buttonsTab.spacing = 16

        tabs.target = self
        tabs.action = #selector(showSelectedTab)
        tabs.selectedSegment = 0
        phoneTab.onClose = { [weak self] in self?.close() }

        for view in [tabs, buttonsTab, phoneTab] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }
        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            tabs.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            buttonsTab.topAnchor.constraint(equalTo: tabs.bottomAnchor, constant: 16),
            buttonsTab.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Self.margin),
            buttonsTab.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Self.margin),
            buttonsTab.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Self.margin),
            buttonsTab.widthAnchor.constraint(equalToConstant: Self.width),

            // Both tabs have the size the Buttons tab needs, so the window keeps its size.
            phoneTab.topAnchor.constraint(equalTo: buttonsTab.topAnchor),
            phoneTab.leadingAnchor.constraint(equalTo: buttonsTab.leadingAnchor),
            phoneTab.trailingAnchor.constraint(equalTo: buttonsTab.trailingAnchor),
            phoneTab.bottomAnchor.constraint(equalTo: buttonsTab.bottomAnchor)
        ])
        for section in sections {
            section.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        }
        showSelectedTab()
    }

    @objc private func showSelectedTab() {
        let showsButtons = tabs.selectedSegment == 0
        buttonsTab.isHidden = !showsButtons
        phoneTab.isHidden = showsButtons
        // Return saves the buttons only while they are in view.
        saveButton.keyEquivalent = showsButtons ? "\r" : ""
    }

    private func createSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }

    private func createHotkeySection() -> NSView {
        modifierButton.target = self
        modifierButton.action = #selector(changeModifiers)
        modifierButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        let changeButton = NSButton(title: "Change", target: self, action: #selector(changeModifiers))

        let row = NSStackView(views: [Self.sectionLabel("Activation Hotkey:"), modifierButton, changeButton])
        row.spacing = 10

        let stack = NSStackView(views: [row, Self.hintLabel("(Click 'Change' and press the new key combination)")])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    private func createGridSection() -> NSView {
        grid.onSelect = { [weak self] id in self?.select(id) }
        grid.onAdd = { [weak self] in self?.addButton() }
        grid.onMove = { [weak self] id, index in
            self?.draft.move(id: id, to: index)
            self?.refresh()
        }
        grid.onDrop = { [weak self] id, file in self?.setIcon(of: id, from: file) }

        gridScrollView.documentView = grid
        gridScrollView.hasVerticalScroller = true
        gridScrollView.scrollerKnobStyle = .light
        gridScrollView.borderType = .noBorder
        gridScrollView.backgroundColor = DeckColor.panel
        gridScrollView.wantsLayer = true
        gridScrollView.layer?.cornerRadius = 16
        gridScrollView.layer?.masksToBounds = true

        let stack = NSStackView(views: [
            Self.sectionLabel("Buttons:"),
            gridScrollView,
            Self.hintLabel("Drop an image or an app on a button to set its icon. Drag a button to reorder.")
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        gridScrollView.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        gridHeight.isActive = true
        return stack
    }

    private func createEditorSection() -> NSView {
        let container = NSView()
        container.heightAnchor.constraint(equalToConstant: Self.editorHeight).isActive = true

        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        editor.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(emptyLabel)
        container.addSubview(editor)

        let icon = createIconColumn()
        let fields = createFieldsColumn()
        icon.translatesAutoresizingMaskIntoConstraints = false
        fields.translatesAutoresizingMaskIntoConstraints = false
        editor.addSubview(icon)
        editor.addSubview(fields)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            editor.topAnchor.constraint(equalTo: container.topAnchor),
            editor.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            editor.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            icon.topAnchor.constraint(equalTo: editor.topAnchor),
            icon.leadingAnchor.constraint(equalTo: editor.leadingAnchor),
            icon.widthAnchor.constraint(equalToConstant: ButtonPreviewView.size.width),

            fields.topAnchor.constraint(equalTo: editor.topAnchor),
            fields.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 24),
            fields.trailingAnchor.constraint(equalTo: editor.trailingAnchor),
            fields.bottomAnchor.constraint(equalTo: editor.bottomAnchor)
        ])
        return container
    }

    private func createIconColumn() -> NSView {
        preview.onDrop = { [weak self] file in
            guard let self = self, let id = self.selectedID else { return }
            self.setIcon(of: id, from: file)
        }
        preview.onClick = { [weak self] in self?.chooseIcon() }

        let hint = NSTextField(wrappingLabelWithString: "Drop an image or an app here, or click to choose")
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .center
        hint.isSelectable = false
        hint.preferredMaxLayoutWidth = ButtonPreviewView.size.width

        removeIconButton.target = self
        removeIconButton.action = #selector(removeIcon)
        removeIconButton.controlSize = .small
        removeIconButton.font = .systemFont(ofSize: NSFont.systemFontSize(for: .small))

        let stack = NSStackView(views: [preview, hint, removeIconButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        hint.widthAnchor.constraint(equalToConstant: ButtonPreviewView.size.width).isActive = true
        return stack
    }

    private func createFieldsColumn() -> NSView {
        nameField.delegate = self
        keyField.delegate = self
        keyField.alignment = .center
        keyField.cell?.allowsUndo = false
        keyField.font = .systemFont(ofSize: 13, weight: .semibold)
        commandView.delegate = self
        commandView.onFocus = { [weak self] focused in self?.commandBox.isFocused = focused }

        let name = Self.column([NSTextField(labelWithString: "Name"), nameBox], spacing: 4)
        let key = Self.column([NSTextField(labelWithString: "Key"), keyBox], spacing: 4)
        keyBox.widthAnchor.constraint(equalToConstant: 64).isActive = true
        let row = NSStackView(views: [name, key])
        row.spacing = 12
        row.alignment = .top
        row.distribution = .fill
        nameBox.widthAnchor.constraint(equalTo: name.widthAnchor).isActive = true
        name.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let command = Self.column([NSTextField(labelWithString: "Command"), commandBox], spacing: 4)
        commandBox.widthAnchor.constraint(equalTo: command.widthAnchor).isActive = true
        commandBox.heightAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true
        commandBox.setContentHuggingPriority(.defaultLow, for: .vertical)

        let deleteButton = NSButton(title: "Delete button", target: self, action: #selector(deleteButton))
        deleteButton.attributedTitle = NSAttributedString(string: "Delete button", attributes: [
            .foregroundColor: FieldBox.red,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ])

        let stack = Self.column([row, keyError, command, commandError, faceError, deleteButton], spacing: 12)
        for view in [row, command] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func createButtonsSection() -> NSView {
        saveButton.target = self
        saveButton.action = #selector(saveConfiguration)
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [spacer, closeButton, saveButton])
        stack.spacing = 10
        stack.distribution = .fill
        closeButton.widthAnchor.constraint(equalToConstant: 84).isActive = true
        saveButton.widthAnchor.constraint(equalToConstant: 84).isActive = true
        return stack
    }

    private static func column(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    private static func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        return label
    }

    private static func hintLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func errorLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 12)
        label.textColor = FieldBox.red
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    // MARK: - Showing the draft

    private func select(_ id: String?) {
        guard id != selectedID else { return }
        selectedID = id
        showSelection()
        refresh()
    }

    /// Fills the fields. Only on a change of button: while one is edited, the fields hold the truth.
    private func showSelection() {
        let button = draft.button(id: selectedID)
        nameField.stringValue = button?.name ?? ""
        keyField.stringValue = button?.key.uppercased() ?? ""
        commandView.string = button?.command ?? ""
        // Undo must not bring one button's text into another.
        window?.undoManager?.removeAllActions()
    }

    private func refresh() {
        modifierButton.title = ModifierNames.text(for: draft.modifiers)
        saveButton.isEnabled = draft.isValid
        refreshGrid()
        refreshEditor()
    }

    private func refreshGrid() {
        grid.tiles = draft.buttons.map { button in
            ButtonGridView.Tile(
                id: button.id,
                face: button.face,
                isSelected: button.id == selectedID,
                isInvalid: !draft.problems(of: button).isEmpty,
                toolTip: button.command
            )
        }

        let height = min(Self.maxGridHeight, ButtonGridView.height(for: draft.buttons.count))
        if height != gridHeight.constant {
            gridHeight.constant = height
            fitWindow()
        }
    }

    /// The window grows and shrinks downwards.
    private func fitWindow() {
        guard let window = window, let contentView = window.contentView else { return }
        let top = window.frame.maxY
        contentView.layoutSubtreeIfNeeded()
        window.setContentSize(contentView.fittingSize)
        window.setFrameTopLeftPoint(NSPoint(x: window.frame.minX, y: top))
    }

    private func refreshEditor() {
        let button = draft.button(id: selectedID)
        editor.isHidden = button == nil
        emptyLabel.isHidden = button != nil
        guard let button = button else { return }

        preview.face = button.face
        removeIconButton.isHidden = button.icon.image == nil

        let problems = draft.problems(of: button)
        show(problems.key, in: keyError)
        show(problems.command, in: commandError)
        show(problems.face, in: faceError)
        keyBox.isInvalid = problems.key != nil
        commandBox.isInvalid = problems.command != nil
    }

    private func show(_ message: String?, in label: NSTextField) {
        label.stringValue = message ?? ""
        label.isHidden = message == nil
    }

    private func edit(_ change: (inout SettingsDraft.Button) -> Void) {
        guard let id = selectedID else { return }
        draft.update(id: id, change)
        refresh()
    }

    // MARK: - Actions

    @objc private func changeModifiers() {
        guard let window = window else { return }
        ChangeHotkeySheet().begin(on: window) { [weak self] modifiers in
            guard let self = self, let modifiers = modifiers else { return }
            self.draft.modifiers = modifiers
            self.refresh()
        }
    }

    private func addButton(icon: SettingsDraft.Button.Icon = .none) {
        select(draft.add(icon: icon))
        // "+" stays in view, ready for the next one.
        grid.scrollToVisible(NSRect(x: 0, y: grid.bounds.maxY - 1, width: 1, height: 1))
    }

    @objc private func deleteButton() {
        guard let id = selectedID else { return }
        draft.remove(id: id)
        select(nil)
    }

    @objc private func removeIcon() {
        edit { $0.icon = .none }
    }

    private func chooseIcon() {
        guard let window = window, let id = selectedID else { return }
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = IconStore.fileTypes
        openPanel.allowsMultipleSelection = false
        openPanel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let file = openPanel.url else { return }
            self?.setIcon(of: id, from: file)
        }
    }

    /// nil adds a new button with the icon.
    private func setIcon(of id: String?, from file: URL) {
        let icon: SettingsDraft.Button.Icon
        do {
            let png = try IconStore.squarePNG(from: file)
            icon = .new(png: png, image: try IconStore.decode(png))
        } catch {
            showAlert("Couldn't read \"\(file.lastPathComponent)\" as an image.", error)
            return
        }
        if let id = id {
            draft.update(id: id) { $0.icon = icon }
            refresh()
        } else {
            addButton(icon: icon)
        }
    }

    @objc private func saveConfiguration() {
        guard draft.isValid else { return }
        do {
            try draft.save(to: configManager, iconStore: iconStore)
        } catch {
            showAlert("Couldn't save the icon.", error)
            return
        }
        onSave?()
        close()
    }

    private func showAlert(_ message: String, _ error: Error) {
        guard let window = window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.beginSheetModal(for: window)
    }

    @objc private func closeWindow() {
        close()
    }

    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        return client as? NSTextField === keyField ? keyEditor : nil
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

// MARK: - NSTextFieldDelegate

extension ConfigurationWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        // Text an input method is still composing.
        if let textView = field.currentEditor() as? NSTextView, textView.hasMarkedText() { return }

        if field === nameField {
            let name = nameField.stringValue.components(separatedBy: .newlines).joined(separator: " ")
            edit { $0.name = name }
        } else if field === keyField {
            keyTyped()
        }
    }

    /// One key at most: a new one takes the place of the old. One that cannot be a hotkey is taken too,
    /// and marked, because an input method can turn W into Ư: refusing it would look like a broken field.
    private func keyTyped() {
        guard let button = draft.button(id: selectedID) else { return }
        var typed = keyField.stringValue.components(separatedBy: .newlines).joined().uppercased()
        if typed.count > 1, let range = typed.range(of: button.key.uppercased()) {
            typed.removeSubrange(range)
        }
        let key = typed.last.map(String.init) ?? ""
        keyField.stringValue = key
        edit { $0.key = key }
    }
}

// MARK: - NSTextViewDelegate

extension ConfigurationWindowController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard notification.object as? NSTextView === commandView else { return }
        let command = commandView.string
        edit { $0.command = command }
    }
}
