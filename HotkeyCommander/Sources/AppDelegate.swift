import Cocoa

@main
class AppMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarItem: NSStatusItem!
    private let menu = NSMenu()
    var configurationWindow: ConfigurationWindowController?
    var hotkeyManager: HotkeyManager!
    var configManager: ConfigurationManager!
    private let iconStore = IconStore()
    private var scriptRunner: ScriptRunner!
    private var panelController: DeckPanelController!
    private var phoneController: PhoneController!
    private let activationMonitor = ActivationMonitor()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize configuration manager
        configManager = ConfigurationManager()

        // Read the PATH scripts run with
        scriptRunner = ScriptRunner(configManager: configManager)
        scriptRunner.prepare()

        // Setup status bar icon BEFORE setting activation policy
        setupStatusBar()

        // Hide dock icon - delay to ensure status bar is created first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
        }

        setupEditMenu()

        // Setup launch at login
        _ = LaunchAtLoginManager.shared

        // Start listening for hotkeys. They need no permission, so they don't wait for the prompt below
        startHotkeys()

        // Build the panel, and show it while the Activation Hotkey is held
        startPanel()

        // Answer the phones, if they are allowed
        phoneController = PhoneController(
            configManager: configManager, iconStore: iconStore, scriptRunner: scriptRunner
        )
        phoneController.start()

        // Request accessibility permissions if needed
        checkAccessibilityPermissions()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        hotkeyManager.stopListening()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    private func startHotkeys() {
        hotkeyManager = HotkeyManager(configManager: configManager)
        hotkeyManager.onHotkey = { [weak self] id in
            self?.activationMonitor.hotkeyPressed()
            self?.scriptRunner.run(id: id)
        }
        hotkeyManager.startListening()
    }

    private func startPanel() {
        panelController = DeckPanelController(configManager: configManager, iconStore: iconStore)
        panelController.onClick = { [weak self] id in
            self?.scriptRunner.run(id: id)
        }

        activationMonitor.onHold = { [weak self] time in
            guard let self = self, self.configManager.isPanelEnabled,
                  self.configurationWindow?.isChangingHotkey != true else {
                return false
            }
            self.panelController.show(hotkeyAt: time)
            return true
        }
        activationMonitor.onEnd = { [weak self] in
            self?.panelController.hide()
        }
        activationMonitor.start(modifiers: configManager.getActivationModifiers())
    }

    private func setupStatusBar() {
        // Create status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusBarItem.button {
            // Load custom menu bar icon
            if let image = NSImage(named: "menubar_icon") {
                image.isTemplate = true
                button.image = image
            } else {
                // Fallback to system icon
                let image = NSImage(named: NSImage.actionTemplateName)
                button.image = image
                button.image?.isTemplate = true
            }
        }

        menu.delegate = self
        statusBarItem.menu = menu
    }

    /// Never on screen, since the app has no menu bar of its own. It is what makes the editing keys work
    /// in the Settings fields.
    private func setupEditMenu() {
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    private func updateMenu() {
        menu.removeAllItems()

        // Add shortcuts list
        let shortcuts = configManager.getShortcuts()
        if shortcuts.isEmpty {
            let item = NSMenuItem(title: "No shortcuts configured", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for shortcut in shortcuts {
                let item = NSMenuItem(title: menuTitle(of: shortcut), action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Show Panel menu item
        let showPanelItem = NSMenuItem(title: "Show Panel", action: #selector(togglePanel), keyEquivalent: "")
        showPanelItem.target = self
        showPanelItem.state = configManager.isPanelEnabled ? .on : .off
        menu.addItem(showPanelItem)

        menu.addItem(NSMenuItem.separator())

        // Configure menu item
        let configureItem = NSMenuItem(title: "Configure…", action: #selector(openConfiguration), keyEquivalent: ",")
        configureItem.target = self
        menu.addItem(configureItem)

        // Quit menu item
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func menuTitle(of shortcut: ShortcutConfig) -> String {
        return shortcut.key.isEmpty ? shortcut.displayName : "\(shortcut.key.uppercased()) - \(shortcut.command.firstLine)"
    }

    @objc private func togglePanel() {
        configManager.setPanelEnabled(!configManager.isPanelEnabled)
        panelController.hide()
    }

    @objc private func openConfiguration() {
        // A window opened anew starts from the saved configuration
        if configurationWindow == nil {
            let controller = ConfigurationWindowController(
                configManager: configManager, iconStore: iconStore, phoneController: phoneController
            )
            controller.onSave = { [weak self] in
                self?.applyConfiguration()
            }
            controller.onClose = { [weak self] in
                // Not during the close itself: this is the last reference to the window
                DispatchQueue.main.async {
                    self?.configurationWindow = nil
                }
            }
            configurationWindow = controller
        }

        configurationWindow?.showWindow(nil)
        configurationWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applyConfiguration() {
        hotkeyManager.reloadConfiguration()
        activationMonitor.setModifiers(configManager.getActivationModifiers())
        panelController.reload()
        phoneController.reload()
    }

    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }

    private func checkAccessibilityPermissions() {
        if AXIsProcessTrusted() {
            return
        }

        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)

        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Hotkey Commander needs accessibility permissions to show the button panel. Shortcuts work without it. Please grant permission in System Preferences > Security & Privacy > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - NSMenuDelegate
extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Refresh menu when it's about to open
        updateMenu()
    }
}
