import Foundation

struct ShortcutConfig: Codable {
    var key: String
    var command: String
}

struct AppConfiguration: Codable {
    var activationModifiers: [String] // e.g., ["control", "shift"]
    var shortcuts: [ShortcutConfig]
}

class ConfigurationManager {
    private let userDefaultsKey = "HotkeyCommanderConfiguration"
    private var configuration: AppConfiguration

    init() {
        // Load configuration from UserDefaults
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let loaded = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
            configuration = loaded
        } else {
            // Default configuration
            configuration = AppConfiguration(
                activationModifiers: ["control", "shift"],
                shortcuts: []
            )
        }
    }

    func getConfiguration() -> AppConfiguration {
        return configuration
    }

    func getActivationModifiers() -> [String] {
        return configuration.activationModifiers
    }

    func getShortcuts() -> [ShortcutConfig] {
        return configuration.shortcuts
    }

    func updateConfiguration(activationModifiers: [String], shortcuts: [ShortcutConfig]) {
        configuration.activationModifiers = activationModifiers
        configuration.shortcuts = shortcuts
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    // Validation methods
    func isValidKey(_ key: String) -> Bool {
        return key.count == 1 && !key.isEmpty
    }

    func isValidCommand(_ command: String) -> Bool {
        return !command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func isValidModifiers(_ modifiers: [String]) -> Bool {
        return !modifiers.isEmpty
    }
}
