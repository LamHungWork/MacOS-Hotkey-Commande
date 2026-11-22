import Cocoa

/// The Phone tab of Settings. Nothing here waits for Save.
final class PhoneSettingsView: NSView {
    var onClose: (() -> Void)?

    private let phones: PhoneController
    private let allowSwitch = NSSwitch()
    private let errorLabel = NSTextField(labelWithString: "")
    private let table = NSTableView()
    private let addButton = NSButton(title: "Add device…", target: nil, action: nil)

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    init(phones: PhoneController) {
        self.phones = phones
        super.init(frame: .zero)
        setupUI()
        refresh()
        phones.onChange = { [weak self] in self?.refresh() }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func refresh() {
        allowSwitch.state = phones.isAllowed ? .on : .off
        errorLabel.stringValue = phones.errorMessage ?? ""
        errorLabel.isHidden = phones.errorMessage == nil
        addButton.isEnabled = phones.isAllowed
        table.reloadData()
    }

    // MARK: - Actions

    @objc private func toggleAllowed() {
        phones.setAllowed(allowSwitch.state == .on)
    }

    @objc private func addDevice() {
        guard let window = window else { return }
        AddDeviceSheet(phones: phones).begin(on: window)
    }

    @objc private func removeDevice(_ sender: NSButton) {
        let row = table.row(for: sender)
        guard phones.devices.indices.contains(row) else { return }
        phones.removeDevice(id: phones.devices[row].id)
    }

    @objc private func close() {
        onClose?()
    }

    // MARK: - Layout

    private func setupUI() {
        allowSwitch.target = self
        allowSwitch.action = #selector(toggleAllowed)
        let allowLabel = NSTextField(labelWithString: "Allow phones")
        allowLabel.font = .systemFont(ofSize: 13, weight: .medium)
        let allowRow = NSStackView(views: [allowSwitch, allowLabel])
        allowRow.spacing = 10

        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.textColor = FieldBox.red

        let warning = NSTextField(labelWithString: "Use only on Wi-Fi you trust. The connection is not encrypted.")
        warning.font = .systemFont(ofSize: 12)
        warning.textColor = .secondaryLabelColor

        addColumn("name", title: "Name", width: 400)
        addColumn("added", title: "Added", width: 160)
        addColumn("remove", title: "", width: 100)
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 32
        table.selectionHighlightStyle = .none
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        let scrollView = NSScrollView()
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)

        addButton.target = self
        addButton.action = #selector(addDevice)
        let closeButton = NSButton(title: "Close", target: self, action: #selector(close))
        closeButton.widthAnchor.constraint(equalToConstant: 84).isActive = true
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [spacer, closeButton])
        buttons.distribution = .fill

        let stack = NSStackView(views: [allowRow, errorLabel, warning, scrollView, addButton, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func addColumn(_ id: String, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        column.title = title
        column.width = width
        table.addTableColumn(column)
    }
}

extension PhoneSettingsView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return phones.devices.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard phones.devices.indices.contains(row) else { return nil }
        let device = phones.devices[row]

        let content: NSView
        switch tableColumn?.identifier.rawValue {
        case "name":
            let label = NSTextField(labelWithString: device.name)
            label.lineBreakMode = .byTruncatingTail
            content = label
        case "added":
            content = NSTextField(labelWithString: Self.dateFormatter.string(from: device.added))
        default:
            let button = NSButton(title: "Remove", target: self, action: #selector(removeDevice(_:)))
            button.controlSize = .small
            content = button
        }

        let cell = NSTableCellView()
        content.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            content.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),
            content.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }
}
