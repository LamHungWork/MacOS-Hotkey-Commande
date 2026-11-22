import Foundation

/// One button of the panel. Records saved before the panel existed hold only `key` and `command`,
/// so every other field has to decode when it is missing.
struct ShortcutConfig: Codable {
    var id: String
    var key: String // "" when the button has no key
    var command: String
    var name: String?
    var icon: String? // file name in IconStore

    init(id: String = UUID().uuidString, key: String, command: String, name: String? = nil, icon: String? = nil) {
        self.id = id
        self.key = key
        self.command = command
        self.name = name
        self.icon = icon
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id) ?? ""
        key = try values.decodeIfPresent(String.self, forKey: .key) ?? ""
        command = try values.decodeIfPresent(String.self, forKey: .command) ?? ""
        name = try values.decodeIfPresent(String.self, forKey: .name)
        icon = try values.decodeIfPresent(String.self, forKey: .icon)
    }

    /// How the button is referred to in text: its name, or its command when it has none.
    var displayName: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? command.firstLine : trimmed
    }
}

struct AppConfiguration: Codable {
    var activationModifiers: [String] // e.g., ["control", "shift"]
    var shortcuts: [ShortcutConfig]
    var showPanel: Bool? // nil means on
    var allowPhones: Bool? // nil means off
    var phones: [PhoneDevice]?
}

extension AppConfiguration {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        activationModifiers = try values.decode([String].self, forKey: .activationModifiers)
        shortcuts = try values.decode([ShortcutConfig].self, forKey: .shortcuts)
        showPanel = try values.decodeIfPresent(Bool.self, forKey: .showPanel)
        allowPhones = try values.decodeIfPresent(Bool.self, forKey: .allowPhones)
        // A device that cannot be read must not cost the buttons.
        phones = try? values.decodeIfPresent([PhoneDevice].self, forKey: .phones)
    }
}

class ConfigurationManager {
    private let userDefaultsKey = "HotkeyCommanderConfiguration"
    private var configuration: AppConfiguration

    init() {
        // Load configuration from UserDefaults
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let loaded = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
            configuration = loaded
            if assignMissingIDs() {
                save()
            }
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

    func getShortcut(id: String) -> ShortcutConfig? {
        return configuration.shortcuts.first { $0.id == id }
    }

    var isPanelEnabled: Bool {
        return configuration.showPanel ?? true
    }

    func setPanelEnabled(_ enabled: Bool) {
        configuration.showPanel = enabled
        save()
    }

    var arePhonesAllowed: Bool {
        return configuration.allowPhones ?? false
    }

    func setPhonesAllowed(_ allowed: Bool) {
        configuration.allowPhones = allowed
        save()
    }

    var phones: [PhoneDevice] {
        return configuration.phones ?? []
    }

    func addPhone(_ phone: PhoneDevice) {
        configuration.phones = phones + [phone]
        save()
    }

    func removePhone(id: String) {
        configuration.phones = phones.filter { $0.id != id }
        save()
    }

    func updateConfiguration(activationModifiers: [String], shortcuts: [ShortcutConfig]) {
        configuration.activationModifiers = activationModifiers
        configuration.shortcuts = shortcuts
        save()
    }

    /// Ids are written back at once, so they are the same after a restart.
    private func assignMissingIDs() -> Bool {
        var seen = Set<String>()
        var changed = false
        for index in configuration.shortcuts.indices {
            if configuration.shortcuts[index].id.isEmpty || seen.contains(configuration.shortcuts[index].id) {
                configuration.shortcuts[index].id = UUID().uuidString
                changed = true
            }
            seen.insert(configuration.shortcuts[index].id)
        }
        return changed
    }

    private func save() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}

extension String {
    /// The first non-empty line, with "…" when more lines follow.
    var firstLine: String {
        let lines = trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
        guard let first = lines.first else { return "" }
        return lines.count > 1 ? first.trimmingCharacters(in: .whitespaces) + "…" : first
    }
}
