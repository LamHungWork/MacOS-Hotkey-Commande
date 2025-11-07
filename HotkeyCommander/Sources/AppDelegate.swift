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
    var configurationWindow: ConfigurationWindowController?
    var hotkeyManager: HotkeyManager!
    var configManager: ConfigurationManager!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize configuration manager
        configManager = ConfigurationManager()

        // Initialize hotkey manager
        hotkeyManager = HotkeyManager(configManager: configManager)

        // Setup status bar icon BEFORE setting activation policy
        setupStatusBar()

        // Hide dock icon - delay to ensure status bar is created first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
        }

        // Setup launch at login
        _ = LaunchAtLoginManager.shared

        // Request accessibility permissions if needed
        checkAccessibilityPermissions()

        // Start listening for hotkeys
        hotkeyManager.startListening()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        hotkeyManager.stopListening()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    private func setupStatusBar() {
        // Create status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusBarItem.button {
            // Use action template icon
            let image = NSImage(named: NSImage.actionTemplateName)
            button.image = image
            button.image?.isTemplate = true
        }

        updateMenu()
    }

    private func updateMenu() {
        let menu = NSMenu()
        menu.delegate = self

        // Add shortcuts list
        let shortcuts = configManager.getShortcuts()
        if shortcuts.isEmpty {
            let item = NSMenuItem(title: "No shortcuts configured", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for shortcut in shortcuts {
                let title = "\(shortcut.key.uppercased()) - \(shortcut.command)"
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Configure menu item
        let configureItem = NSMenuItem(title: "Configure...", action: #selector(openConfiguration), keyEquivalent: ",")
        configureItem.target = self
        menu.addItem(configureItem)

        // Quit menu item
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Set menu
        statusBarItem.menu = menu
    }

    @objc private func openConfiguration() {
        if configurationWindow == nil {
            configurationWindow = ConfigurationWindowController(configManager: configManager, hotkeyManager: hotkeyManager)
        }

        configurationWindow?.showWindow(nil)
        configurationWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Update menu after configuration window closes
        configurationWindow?.onClose = { [weak self] in
            self?.updateMenu()
        }
    }

    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }

    private func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Hotkey Commander needs accessibility permissions to listen for global keyboard shortcuts. Please grant permission in System Preferences > Security & Privacy > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// MARK: - NSMenuDelegate
extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Refresh menu when it's about to open
        updateMenu()
    }
}
