import Cocoa
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager!
    private var configManager: ConfigManager!
    private var appLauncher: AppLauncher!
    private var systemTrayManager: SystemTrayManager!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("AppDelegate: Application did finish launching")
        
        // Ensure only one instance of the app is running
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.miwatech.appshortcuts")
        if runningApps.count > 1 {
            NSLog("AppDelegate: Another instance is already running. Terminating this instance.")
            NSApplication.shared.terminate(nil)
            return
        }
        
        // Set application activation policy to background (menu bar only)
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Initialize managers
        NSLog("AppDelegate: Initializing ConfigManager")
        configManager = ConfigManager()
        
        NSLog("AppDelegate: Initializing HotkeyManager")
        hotkeyManager = HotkeyManager()
        
        NSLog("AppDelegate: Initializing AppLauncher")
        appLauncher = AppLauncher()
        
        // Register hotkeys from config
        NSLog("AppDelegate: Registering hotkeys")
        registerHotkeys()
        
        // Setup system tray icon and menu
        NSLog("AppDelegate: Setting up system tray")
        systemTrayManager = SystemTrayManager(
            configManager: configManager,
            appLauncher: appLauncher,
            reloadCallback: { [weak self] in
                NSLog("AppDelegate: Reload callback triggered")
                self?.reloadConfiguration()
            },
            toggleAutoStartCallback: { [weak self] in
                NSLog("AppDelegate: Toggle auto-start callback triggered")
                self?.toggleAutoStart()
            },
            isAutoStartEnabled: LaunchAgentManager.shared.isLaunchAgentInstalled
        )
        
        // Request accessibility permissions if needed
        NSLog("AppDelegate: Checking accessibility permissions")
        requestAccessibilityPermissionsIfNeeded()
        
        // Log startup information
        NSLog("AppDelegate: Application startup completed successfully")
        
        // Print information about active shortcuts
        for shortcut in configManager.getShortcuts() {
            let keyString = ConfigManager.keyCodeToString(shortcut.keyCode)
            let modString = ConfigManager.modifiersToString(shortcut.modifiers)
            NSLog("AppDelegate: Active shortcut - \(shortcut.name): \(modString)\(keyString) (keyCode: \(shortcut.keyCode), modifiers: \(shortcut.modifiers))")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up resources
        NSLog("AppDelegate: Application will terminate")
        hotkeyManager.unregisterAllHotkeys()
    }
    
    private func registerHotkeys() {
        NSLog("AppDelegate: Beginning to register hotkeys")
        
        // Unregister any existing hotkeys first
        hotkeyManager.unregisterAllHotkeys()
        
        // Register application shortcuts
        let shortcuts = configManager.getShortcuts()
        NSLog("AppDelegate: Found \(shortcuts.count) application shortcuts to register")
        
        for shortcut in shortcuts {
            NSLog("AppDelegate: Registering shortcut for \(shortcut.name) - keyCode: \(shortcut.keyCode), modifiers: \(shortcut.modifiers)")
            hotkeyManager.registerHotkey(
                keyCode: shortcut.keyCode,
                modifiers: shortcut.modifiers,
                id: shortcut.id
            ) { [weak self] in
                NSLog("AppDelegate: Hotkey handler triggered for \(shortcut.name)")
                self?.appLauncher.launchApplication(bundleIdentifier: shortcut.bundleIdentifier)
            }
        }
        
        // Register system commands if defined in config
        let commands = configManager.getSystemCommands()
        NSLog("AppDelegate: Found \(commands.count) system commands to register")
        
        for command in commands {
            NSLog("AppDelegate: Registering command \(command.name) - keyCode: \(command.keyCode), modifiers: \(command.modifiers)")
            hotkeyManager.registerHotkey(
                keyCode: command.keyCode,
                modifiers: command.modifiers,
                id: command.id
            ) { [weak self] in
                NSLog("AppDelegate: System command handler triggered for \(command.name)")
                self?.handleSystemCommand(command: command.command)
            }
        }
        
        NSLog("AppDelegate: Finished registering hotkeys")
    }
    
    private func reloadConfiguration() {
        // Reload configuration
        configManager.reloadConfiguration()
        
        // Re-register hotkeys
        registerHotkeys()
        
        NSLog("Configuration reloaded")
    }
    
    private func handleSystemCommand(command: String) {
        NSLog("Executing system command: \(command)")
        
        switch command {
        case "reload":
            reloadConfiguration()
        case "sleep", "restart", "shutdown":
            appLauncher.executeSystemCommand(command)
        default:
            NSLog("Unsupported command: \(command)")
        }
    }
    
    private func toggleAutoStart() {
        if LaunchAgentManager.shared.isLaunchAgentInstalled {
            if LaunchAgentManager.shared.uninstallLaunchAgent() {
                showNotification(title: "AppShortcuts", message: "Auto-start disabled")
                systemTrayManager.updateAutoStartStatus(isEnabled: false)
            } else {
                showNotification(title: "AppShortcuts", message: "Failed to disable auto-start")
            }
        } else {
            if LaunchAgentManager.shared.installLaunchAgent() {
                showNotification(title: "AppShortcuts", message: "Auto-start enabled")
                systemTrayManager.updateAutoStartStatus(isEnabled: true)
            } else {
                showNotification(title: "AppShortcuts", message: "Failed to enable auto-start")
            }
        }
    }
    
    private func requestAccessibilityPermissionsIfNeeded() {
        // First check without prompting
        let accessEnabled = AXIsProcessTrusted()
        
        if !accessEnabled {
            NSLog("Accessibility permissions not granted. Prompting user...")
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "AppShortcuts needs accessibility permissions to capture global hotkeys. Please open System Preferences and enable AppShortcuts in Privacy & Security > Privacy > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Later")
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
            }
        } else {
            NSLog("Accessibility permissions granted")
        }
    }
    
    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}