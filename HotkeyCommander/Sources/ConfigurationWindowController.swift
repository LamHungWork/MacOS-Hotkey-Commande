import Cocoa

class ConfigurationWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private var configManager: ConfigurationManager
    private var hotkeyManager: HotkeyManager

    // Temporary storage for editing
    private var tempModifiers: [String] = []
    private var tempShortcuts: [ShortcutConfig] = []

    // UI Components
    private var modifierButton: NSButton!
    private var tableView: NSTableView!
    private var keyField: NSTextField!
    private var commandField: NSTextField!
    private var addButton: NSButton!
    private var saveButton: NSButton!
    private var closeButton: NSButton!

    var onClose: (() -> Void)?

    init(configManager: ConfigurationManager, hotkeyManager: HotkeyManager) {
        self.configManager = configManager
        self.hotkeyManager = hotkeyManager

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Hotkey Commander Settings"
        window.center()

        super.init(window: window)
        window.delegate = self

        // Load current configuration into temp storage
        loadConfiguration()
        setupUI()
        validateForm()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func loadConfiguration() {
        let config = configManager.getConfiguration()
        tempModifiers = config.activationModifiers
        tempShortcuts = config.shortcuts
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        // Main container
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 20
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // Activation Hotkey Section
        let hotkeySection = createHotkeySection()
        mainStack.addArrangedSubview(hotkeySection)

        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        mainStack.addArrangedSubview(separator)

        // Shortcuts Section
        let shortcutsSection = createShortcutsSection()
        mainStack.addArrangedSubview(shortcutsSection)

        // Add New Section
        let addSection = createAddSection()
        mainStack.addArrangedSubview(addSection)

        // Buttons Section
        let buttonsSection = createButtonsSection()
        mainStack.addArrangedSubview(buttonsSection)

        // Set priorities
        shortcutsSection.setContentHuggingPriority(.defaultLow, for: .vertical)
    }

    private func createHotkeySection() -> NSView {
        let container = NSView()

        let label = NSTextField(labelWithString: "Activation Hotkey:")
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        modifierButton = NSButton(title: formatModifiers(tempModifiers), target: self, action: #selector(changeModifiers))
        modifierButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(modifierButton)

        let infoLabel = NSTextField(labelWithString: "(Click 'Change' and press the new key combination)")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(infoLabel)

        let changeButton = NSButton(title: "Change", target: self, action: #selector(changeModifiers))
        changeButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(changeButton)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            modifierButton.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            modifierButton.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            modifierButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),

            changeButton.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            changeButton.leadingAnchor.constraint(equalTo: modifierButton.trailingAnchor, constant: 10),

            infoLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 5),
            infoLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            infoLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func createShortcutsSection() -> NSView {
        let container = NSView()

        let label = NSTextField(labelWithString: "Shortcuts:")
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder

        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = NSTableHeaderView()
        tableView.usesAlternatingRowBackgroundColors = true

        let keyColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("key"))
        keyColumn.title = "Key"
        keyColumn.width = 80
        tableView.addTableColumn(keyColumn)

        let commandColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("command"))
        commandColumn.title = "Command"
        commandColumn.width = 350
        tableView.addTableColumn(commandColumn)

        let deleteColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("delete"))
        deleteColumn.title = ""
        deleteColumn.width = 50
        tableView.addTableColumn(deleteColumn)

        scrollView.documentView = tableView
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            scrollView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])

        return container
    }

    private func createAddSection() -> NSView {
        let container = NSView()

        let keyLabel = NSTextField(labelWithString: "Key:")
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(keyLabel)

        keyField = NSTextField()
        keyField.placeholderString = "S"
        keyField.translatesAutoresizingMaskIntoConstraints = false
        keyField.delegate = self
        container.addSubview(keyField)

        let commandLabel = NSTextField(labelWithString: "Command:")
        commandLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(commandLabel)

        commandField = NSTextField()
        commandField.placeholderString = "open -a \"Google Chrome\""
        commandField.translatesAutoresizingMaskIntoConstraints = false
        commandField.delegate = self
        container.addSubview(commandField)

        addButton = NSButton(title: "+ Add New", target: self, action: #selector(addNewShortcut))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(addButton)

        NSLayoutConstraint.activate([
            keyLabel.topAnchor.constraint(equalTo: container.topAnchor),
            keyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            keyLabel.widthAnchor.constraint(equalToConstant: 80),

            keyField.centerYAnchor.constraint(equalTo: keyLabel.centerYAnchor),
            keyField.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor, constant: 5),
            keyField.widthAnchor.constraint(equalToConstant: 50),

            commandLabel.centerYAnchor.constraint(equalTo: keyLabel.centerYAnchor),
            commandLabel.leadingAnchor.constraint(equalTo: keyField.trailingAnchor, constant: 15),
            commandLabel.widthAnchor.constraint(equalToConstant: 80),

            commandField.centerYAnchor.constraint(equalTo: keyLabel.centerYAnchor),
            commandField.leadingAnchor.constraint(equalTo: commandLabel.trailingAnchor, constant: 5),
            commandField.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            addButton.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 10),
            addButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            addButton.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func createButtonsSection() -> NSView {
        let container = NSView()

        closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(closeButton)

        saveButton = NSButton(title: "Save", target: self, action: #selector(saveConfiguration))
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.keyEquivalent = "\r" // Enter key
        container.addSubview(saveButton)

        NSLayoutConstraint.activate([
            saveButton.topAnchor.constraint(equalTo: container.topAnchor),
            saveButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            saveButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 80),

            closeButton.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -10),
            closeButton.widthAnchor.constraint(equalToConstant: 80)
        ])

        return container
    }

    @objc private func changeModifiers() {
        let alert = NSAlert()
        alert.messageText = "Press New Hotkey Combination"
        alert.informativeText = "Press the modifier keys you want to use (Control, Shift, Command, Option)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Cancel")

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputField.placeholderString = "Press modifiers..."
        inputField.isEditable = false
        alert.accessoryView = inputField

        // Capture key events
        var capturedModifiers: [String] = []
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            capturedModifiers = []

            if flags.contains(.control) { capturedModifiers.append("control") }
            if flags.contains(.shift) { capturedModifiers.append("shift") }
            if flags.contains(.command) { capturedModifiers.append("command") }
            if flags.contains(.option) { capturedModifiers.append("option") }

            inputField.stringValue = self.formatModifiers(capturedModifiers)
            return event
        }

        let response = alert.runModal()
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }

        if response == .alertFirstButtonReturn { // Cancel
            return
        }

        if !capturedModifiers.isEmpty {
            tempModifiers = capturedModifiers
            modifierButton.title = formatModifiers(tempModifiers)
            validateForm()
        }
    }

    @objc private func addNewShortcut() {
        let key = keyField.stringValue.trimmingCharacters(in: .whitespaces)
        let command = commandField.stringValue.trimmingCharacters(in: .whitespaces)

        guard configManager.isValidKey(key) && configManager.isValidCommand(command) else {
            return
        }

        // Check for duplicate keys
        if tempShortcuts.contains(where: { $0.key.lowercased() == key.lowercased() }) {
            let alert = NSAlert()
            alert.messageText = "Duplicate Key"
            alert.informativeText = "A shortcut with this key already exists."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        tempShortcuts.append(ShortcutConfig(key: key, command: command))
        tableView.reloadData()

        keyField.stringValue = ""
        commandField.stringValue = ""
        validateForm()
    }

    @objc private func saveConfiguration() {
        configManager.updateConfiguration(activationModifiers: tempModifiers, shortcuts: tempShortcuts)
        hotkeyManager.reloadConfiguration()
        close()
    }

    @objc private func closeWindow() {
        close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    private func formatModifiers(_ modifiers: [String]) -> String {
        let formatted = modifiers.map { modifier -> String in
            switch modifier.lowercased() {
            case "control": return "Control"
            case "shift": return "Shift"
            case "command": return "Command"
            case "option": return "Option"
            default: return modifier.capitalized
            }
        }
        return formatted.joined(separator: " + ")
    }

    private func validateForm() {
        let modifiersValid = configManager.isValidModifiers(tempModifiers)
        let shortcutsValid = tempShortcuts.allSatisfy { shortcut in
            configManager.isValidKey(shortcut.key) && configManager.isValidCommand(shortcut.command)
        }

        saveButton.isEnabled = modifiersValid && shortcutsValid
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return tempShortcuts.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < tempShortcuts.count else { return nil }

        let shortcut = tempShortcuts[row]
        let identifier = tableColumn?.identifier

        if identifier == NSUserInterfaceItemIdentifier("key") {
            let cellView = NSTableCellView()
            let textField = NSTextField(labelWithString: shortcut.key.uppercased())
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            return cellView
        } else if identifier == NSUserInterfaceItemIdentifier("command") {
            let cellView = NSTableCellView()
            let textField = NSTextField(labelWithString: shortcut.command)
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                textField.trailingAnchor.constraint(lessThanOrEqualTo: cellView.trailingAnchor, constant: -5)
            ])
            return cellView
        } else if identifier == NSUserInterfaceItemIdentifier("delete") {
            let cellView = NSTableCellView()
            let button = NSButton(title: "×", target: self, action: #selector(deleteShortcut(_:)))
            button.tag = row
            button.isBordered = false
            button.font = NSFont.systemFont(ofSize: 16)
            button.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(button)
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: cellView.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            return cellView
        }

        return nil
    }

    @objc private func deleteShortcut(_ sender: NSButton) {
        let row = sender.tag
        guard row < tempShortcuts.count else { return }

        tempShortcuts.remove(at: row)
        tableView.reloadData()
        validateForm()
    }
}

// MARK: - NSTextFieldDelegate

extension ConfigurationWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        validateForm()
    }
}
