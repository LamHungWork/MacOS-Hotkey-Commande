import Cocoa
import ServiceManagement

class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private let launchAtLoginKey = "LaunchAtLogin"

    private init() {
        // Enable launch at login by default
        if UserDefaults.standard.object(forKey: launchAtLoginKey) == nil {
            setLaunchAtLogin(enabled: true)
        }
    }

    func isLaunchAtLoginEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: launchAtLoginKey)
    }

    func setLaunchAtLogin(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: launchAtLoginKey)

        if #available(macOS 13.0, *) {
            // Modern API for macOS 13+
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        } else {
            // Legacy API for older macOS versions
            let success = SMLoginItemSetEnabled("com.hotkeycommander.launcher" as CFString, enabled)
            if !success {
                print("Failed to \(enabled ? "enable" : "disable") launch at login")
            }
        }
    }
}
